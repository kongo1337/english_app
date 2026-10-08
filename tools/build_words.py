#!/usr/bin/env python3
"""Validate the data pipeline output and build App/Resources/words.json.

Usage: python3 -I tools/build_words.py

Inputs (all committed, no network needed):
  data/interim/oxford_lemmas.csv         from tools/extract_oxford.py
  data/interim/translations/batch_*.psv  id | ru | example_en | example_ru
  data/interim/ipa.tsv                   from tools/extract_ipa.py
  data/overrides.csv                     manual fixes: id,field,value
"""
from __future__ import annotations

import collections
import csv
import json
import re
import sys
from pathlib import Path

LEMMAS = Path("data/interim/oxford_lemmas.csv")
TRANSLATIONS = Path("data/interim/translations")
IPA = Path("data/interim/ipa.tsv")
OVERRIDES = Path("data/overrides.csv")
OUT = Path("App/Resources/words.json")

VERSION = 1
LEVELS = {"ox3000": {"A1", "A2", "B1", "B2"}, "ox5000": {"B2", "C1"}}
POS = {"noun", "verb", "adjective", "adverb", "preposition", "conjunction", "pronoun",
       "determiner", "number", "exclamation", "modal", "auxiliary", "article", "other"}
OVERRIDE_FIELDS = {"translations", "exampleEN", "exampleRU", "ipa", "sense"}
CYRILLIC = re.compile(r"[А-Яа-яЁё]")
LATIN = re.compile(r"[A-Za-z]")
MAX_EXAMPLE_WORDS = 15


def load_translations() -> dict[str, dict]:
    result: dict[str, dict] = {}
    for path in sorted(TRANSLATIONS.glob("batch_*.psv")):
        for line in path.read_text(encoding="utf-8").splitlines()[1:]:
            wid, ru, en, ru_example = (c.strip() for c in line.split(" | "))
            result[wid] = {
                "translations": [t.strip() for t in ru.split(";") if t.strip()],
                "exampleEN": en,
                "exampleRU": ru_example,
            }
    return result


def load_ipa() -> dict[str, str]:
    rows = csv.DictReader(IPA.open(encoding="utf-8"), delimiter="\t")
    return {row["lemma"]: row["ipa"] for row in rows}


def apply_overrides(words: dict[str, dict], errors: list[str]) -> int:
    count = 0
    for row in csv.DictReader(OVERRIDES.open(encoding="utf-8")):
        wid, field, value = row["id"], row["field"], row["value"]
        if wid not in words:
            errors.append(f"overrides: unknown id {wid}")
        elif field not in OVERRIDE_FIELDS:
            errors.append(f"overrides: unknown field {field} for {wid}")
        else:
            words[wid][field] = [t.strip() for t in value.split(";")] if field == "translations" else value
            count += 1
    return count


def mentions_lemma(example: str, lemma: str) -> bool:
    # Accept inflected forms: "abandoned" for abandon, "children" is too irregular to check.
    stems = [w[:max(3, len(w) - 2)].lower() for w in re.split(r"[\s,]+", lemma) if w]
    text = example.lower()
    return all(stem in text for stem in stems)


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    translations = load_translations()
    ipa = load_ipa()

    words: dict[str, dict] = {}
    for row in csv.DictReader(LEMMAS.open(encoding="utf-8")):
        wid = row["id"]
        if wid in words:
            errors.append(f"duplicate id {wid}")
            continue
        t = translations.get(wid)
        if t is None:
            errors.append(f"no translation for {wid}")
            continue
        words[wid] = {
            "id": wid,
            "lemma": row["lemma"],
            "sense": row["sense"] or None,
            "pos": row["pos"],
            "cefr": row["cefr"],
            "list": row["list"],
            "ipa": ipa.get(row["lemma"]),
            **t,
            "order": int(row["order"]),
        }
    extra = set(translations) - set(words)
    if extra:
        errors.append(f"translations for unknown ids: {sorted(extra)}")
    overridden = apply_overrides(words, errors)

    for w in words.values():
        wid = w["id"]
        if w["pos"] not in POS:
            errors.append(f"{wid}: bad pos {w['pos']}")
        if w["cefr"] not in LEVELS.get(w["list"], set()):
            errors.append(f"{wid}: level {w['cefr']} not allowed in {w['list']}")
        if not 1 <= len(w["translations"]) <= 3:
            warnings.append(f"{wid}: {len(w['translations'])} translations")
        for tr in w["translations"]:
            if not CYRILLIC.search(tr):
                errors.append(f"{wid}: translation without cyrillic: {tr!r}")
            elif LATIN.search(tr):
                warnings.append(f"{wid}: latin letters in translation: {tr!r}")
        if not CYRILLIC.search(w["exampleRU"]):
            errors.append(f"{wid}: russian example without cyrillic")
        if not mentions_lemma(w["exampleEN"], w["lemma"]):
            warnings.append(f"{wid}: example may not contain the word: {w['exampleEN']!r}")
        if len(w["exampleEN"].split()) > MAX_EXAMPLE_WORDS:
            warnings.append(f"{wid}: long example ({len(w['exampleEN'].split())} words)")
        if not w["ipa"]:
            warnings.append(f"{wid}: no ipa")

    by_lemma: dict[tuple, list[dict]] = collections.defaultdict(list)
    for w in words.values():
        by_lemma[(w["list"], w["lemma"])].append(w)
    for group in by_lemma.values():
        firsts = collections.Counter(w["translations"][0] for w in group)
        for tr, n in firsts.items():
            if n > 1:
                warnings.append(f"{group[0]['lemma']}: same main translation {tr!r} for {n} parts of speech")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        print(f"FAILED: {len(errors)} error(s)", file=sys.stderr)
        return 1

    ordered = sorted(words.values(), key=lambda w: (w["list"], w["order"]))
    counts = collections.Counter(w["list"] for w in ordered)
    payload = {
        "version": VERSION,
        "counts": dict(sorted(counts.items())),
        "words": ordered,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
                   encoding="utf-8")
    report = Path("data/interim/build_report.txt")
    report.write_text("\n".join(warnings) + "\n", encoding="utf-8")
    print(f"wrote {len(ordered)} words to {OUT} ({OUT.stat().st_size // 1024} KB): {dict(counts)}")
    print(f"  {overridden} overrides applied, {len(warnings)} warnings in {report}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
