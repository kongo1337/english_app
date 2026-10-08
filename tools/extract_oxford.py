#!/usr/bin/env python3
"""Extract Oxford 3000 / 5000 word lists from the official PDFs into a CSV.

Usage: python3 tools/extract_oxford.py [--raw data/raw] [--out data/interim/oxford_lemmas.csv]

Requires `pdftotext` (poppler): `brew install poppler` on macOS.
"""
from __future__ import annotations

import argparse
import collections
import csv
import re
import subprocess
import sys
from pathlib import Path

LEVELS = ("A1", "A2", "B1", "B2", "C1")

POS_MAP = {
    "n.": "noun",
    "v.": "verb",
    "adj.": "adjective",
    "adv.": "adverb",
    "prep.": "preposition",
    "conj.": "conjunction",
    "pron.": "pronoun",
    "det.": "determiner",
    "exclam.": "exclamation",
    "number": "number",
    "modal v.": "modal",
    "auxiliary v.": "auxiliary",
    "indefinite article": "article",
    "definite article": "article",
    "infinitive marker": "other",
}

# Longest first so "modal v." wins over "v.".
_POS_ALT = "|".join(re.escape(p) for p in sorted(POS_MAP, key=len, reverse=True))
POS_ONLY_RE = re.compile(rf"^(?:(?:{_POS_ALT})\s*[,/]?\s*)+$")
ENTRY_RE = re.compile(
    rf"^(?P<head>.+?)\s+(?P<pos>(?:(?:{_POS_ALT})\s*[,/]?\s*)+)$"
)
HEAD_RE = re.compile(r"^(?P<lemma>.+?)(?P<homonym>\d)?(?:\s+\((?P<sense>[^)]+)\))?$")
NOISE_RE = re.compile(r"^(\d+\s*/\s*\d+|©.*|The Oxford \d+.*|.*is the list of.*|"
                      r".*expanded core word list.*|3000, it includes.*)$")

SOURCES = (("ox3000", "oxford3000.pdf"), ("ox5000", "oxford5000.pdf"))


def slug(text: str) -> str:
    # Case is kept on purpose: "March" (month) and "march" (walk) are different words.
    return re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-")


def pdf_lines(path: Path) -> list[str]:
    text = subprocess.run(["pdftotext", str(path), "-"], check=True,
                          capture_output=True, text=True).stdout
    return [line.strip() for line in text.splitlines()]


def join_wrapped(lines: list[str]) -> list[str]:
    """Glue entries that the PDF wrapped onto two lines, e.g. 'light (...) n.,' + 'adj.'."""
    out: list[str] = []
    for line in lines:
        if not line or NOISE_RE.match(line):
            continue
        if out and POS_ONLY_RE.match(line) and line not in LEVELS and out[-1] not in LEVELS:
            if out[-1].rstrip().endswith((",", "/")):
                out[-1] = f"{out[-1]} {line}"
                continue
        out.append(line)
    return out


def parse(list_id: str, path: Path) -> tuple[list[dict], list[str]]:
    entries: list[dict] = []
    errors: list[str] = []
    level: str | None = None
    for line in join_wrapped(pdf_lines(path)):
        if line in LEVELS:
            level = line
            continue
        m = ENTRY_RE.match(line)
        if not m or level is None:
            errors.append(f"{path.name}: cannot parse {line!r}")
            continue
        head = HEAD_RE.match(m.group("head"))
        assert head is not None
        lemma = head.group("lemma").strip()
        homonym = head.group("homonym") or ""
        sense = head.group("sense") or ""
        pos_tokens = [p.strip() for p in re.split(r"[,/]", m.group("pos")) if p.strip()]
        seen_pos: set[str] = set()
        for token in pos_tokens:
            pos = POS_MAP[token]
            if pos in seen_pos:  # "indefinite article" + "definite article" etc.
                continue
            seen_pos.add(pos)
            suffix = "".join(f"-{part}" for part in (homonym, slug(sense).lower()) if part)
            entries.append({
                "id": f"{slug(lemma)}{suffix}_{pos}",
                "lemma": lemma,
                "homonym": homonym,
                "sense": sense,
                "pos": pos,
                "cefr": level,
                "list": list_id,
            })
    return entries, errors


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--raw", type=Path, default=Path("data/raw"))
    ap.add_argument("--out", type=Path, default=Path("data/interim/oxford_lemmas.csv"))
    args = ap.parse_args()

    rows: list[dict] = []
    errors: list[str] = []
    seen: dict[str, dict] = {}
    duplicates: list[str] = []
    for list_id, filename in SOURCES:
        entries, errs = parse(list_id, args.raw / filename)
        errors += errs
        for entry in entries:
            if entry["id"] in seen:
                first = seen[entry["id"]]
                duplicates.append(f"{entry['id']}: {first['list']}/{first['cefr']} "
                                  f"kept, {entry['list']}/{entry['cefr']} dropped")
                continue
            seen[entry["id"]] = entry
            rows.append(entry)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    order = collections.Counter()
    for row in rows:
        order[row["list"]] += 1
        row["order"] = order[row["list"]]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "lemma", "homonym", "sense", "pos",
                                               "cefr", "list", "order"])
        writer.writeheader()
        writer.writerows(rows)

    counts = collections.Counter((r["list"], r["cefr"]) for r in rows)
    headwords = collections.Counter(r["list"] for r in {(r["list"], r["lemma"], r["homonym"],
                                                        r["sense"]): r for r in rows}.values())
    print(f"wrote {len(rows)} entries to {args.out}")
    for list_id, _ in SOURCES:
        per_level = ", ".join(f"{lvl}={counts[(list_id, lvl)]}" for lvl in LEVELS
                              if counts[(list_id, lvl)])
        print(f"  {list_id}: {order[list_id]} entries, {headwords[list_id]} headwords ({per_level})")
    if duplicates:
        print(f"  {len(duplicates)} duplicate ids dropped:")
        for d in duplicates:
            print(f"    {d}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
