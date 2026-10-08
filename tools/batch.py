#!/usr/bin/env python3
"""Print batch N of oxford_lemmas.csv (100 rows) for translation: `python3 tools/batch.py 1`."""
import csv
import sys

SIZE = 100
n = int(sys.argv[1])
rows = list(csv.DictReader(open("data/interim/oxford_lemmas.csv", encoding="utf-8")))
print(f"# batch {n:03d} of {(len(rows) + SIZE - 1) // SIZE}")
for r in rows[(n - 1) * SIZE:n * SIZE]:
    print(r["id"], r["cefr"])
