#!/usr/bin/env python3
"""Write a review sheet for manual checking of translations: data/interim/review_sample.md.

Usage: python3 -I tools/sample.py [--size 100] [--seed 42]

The sheet holds a fixed random sample plus every A1–A2 lemma that has several parts of
speech: these are the most frequent and most ambiguous words. Fixes go to data/overrides.csv.
"""
from __future__ import annotations

import argparse
import collections
import json
import random
from pathlib import Path

WORDS = Path("App/Resources/words.json")
OUT = Path("data/interim/review_sample.md")


def row(w: dict) -> str:
    head = w["lemma"] + (f" ({w['sense']})" if w["sense"] else "")
    return (f"| `{w['id']}` | {head} | {w['pos']} | {w['cefr']} | "
            f"{'; '.join(w['translations'])} | {w['exampleEN']} — {w['exampleRU']} |")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--size", type=int, default=100)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    words = json.loads(WORDS.read_text(encoding="utf-8"))["words"]
    sample = random.Random(args.seed).sample(words, args.size)

    by_lemma = collections.defaultdict(list)
    for w in words:
        if w["cefr"] in ("A1", "A2"):
            by_lemma[w["lemma"]].append(w)
    polysemous = [w for group in by_lemma.values() if len(group) > 1 for w in group]

    header = ["| id | слово | часть речи | уровень | перевод | пример |",
              "|----|-------|------------|---------|---------|--------|"]
    lines = [
        "# Выборка для ручной проверки переводов",
        "",
        "Исправления вносятся в `data/overrides.csv` (`id,field,value`), затем `make data`.",
        "",
        f"## Случайные {args.size} записей (seed {args.seed})",
        "",
        *header,
        *(row(w) for w in sample),
        "",
        f"## Многозначные слова A1–A2 ({len(polysemous)} записей)",
        "",
        *header,
        *(row(w) for w in polysemous),
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {args.size} + {len(polysemous)} rows to {OUT}")


if __name__ == "__main__":
    main()
