#!/usr/bin/env python3
"""Extract IPA transcriptions for our lemmas from open-dict-data/ipa-dict (MIT licence).

Usage:
  mkdir -p data/raw/ipa-dict && curl -sSf -o data/raw/ipa-dict/en_US.txt \\
      https://raw.githubusercontent.com/open-dict-data/ipa-dict/master/data/en_US.txt
  python3 -I tools/extract_ipa.py

Writes data/interim/ipa.tsv (lemma<TAB>ipa) which is committed, so building words.json
needs no network. American transcription is used: ipa-dict's en_UK file is much less
accurate. Up to two variants are kept ("/ˈkloʊs/, /ˈkloʊz/"); heteronyms such as
close (adj) vs close (verb) can be fixed per id in data/overrides.csv.
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

SOURCE = Path("data/raw/ipa-dict/en_US.txt")
LEMMAS = Path("data/interim/oxford_lemmas.csv")
OUT = Path("data/interim/ipa.tsv")
MAX_VARIANTS = 2

# ipa-dict uses narrow symbols that learners' dictionaries do not.
NORMALIZE = str.maketrans({"ɫ": "l", "ɹ": "r"})

# The American dictionary lacks British spellings used by Oxford; look these up instead.
US_SPELLING = {
    "analyse": "analyze", "colourful": "colorful", "councillor": "councilor",
    "counselling": "counseling", "enrol": "enroll", "favourable": "favorable",
    "flavour": "flavor", "jewellery": "jewelry", "litre": "liter", "maths": "math",
    "offence": "offense", "sceptical": "skeptical",
}
MANUAL = {"a, an": "/ə/, /æn/"}


def load_dict(path: Path) -> dict[str, list[str]]:
    entries: dict[str, list[str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        word, _, ipa = line.partition("\t")
        variants = [v.strip().strip("/").translate(NORMALIZE) for v in ipa.split(",")]
        entries[word.lower()] = [v for v in variants if v]
    return entries


def transcribe(lemma: str, dictionary: dict[str, list[str]]) -> str | None:
    if lemma in MANUAL:
        return MANUAL[lemma]
    key = lemma.lower().replace("’", "'")
    key = US_SPELLING.get(key, key)
    if key in dictionary:
        variants = dictionary[key][:MAX_VARIANTS]
        return ", ".join(f"/{v}/" for v in variants)
    # Multi-word lemmas ("have to", "ice cream", "according to"): first variant of each word.
    words = re.split(r"[\s-]+", key)
    if len(words) > 1 and all(w in dictionary for w in words):
        return "/" + " ".join(dictionary[w][0] for w in words) + "/"
    return None


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE}; see the usage in this file's docstring", file=sys.stderr)
        return 1
    dictionary = load_dict(SOURCE)
    lemmas = sorted({row["lemma"] for row in csv.DictReader(LEMMAS.open(encoding="utf-8"))})
    found, missing = {}, []
    for lemma in lemmas:
        ipa = transcribe(lemma, dictionary)
        if ipa:
            found[lemma] = ipa
        else:
            missing.append(lemma)
    with OUT.open("w", encoding="utf-8") as f:
        f.write("lemma\tipa\n")
        for lemma in lemmas:
            if lemma in found:
                f.write(f"{lemma}\t{found[lemma]}\n")
    print(f"wrote {len(found)} of {len(lemmas)} lemmas to {OUT}")
    print(f"  {len(missing)} without transcription: {', '.join(missing)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
