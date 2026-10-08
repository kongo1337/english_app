#!/usr/bin/env python3
"""Check translation batches against oxford_lemmas.csv: `python3 tools/check_batch.py [N ...]`."""
import csv
import re
import sys
from pathlib import Path

SIZE = 100
CYRILLIC = re.compile(r"[А-Яа-яЁё]")
rows = list(csv.DictReader(open("data/interim/oxford_lemmas.csv", encoding="utf-8")))
batches = [int(a) for a in sys.argv[1:]] or [
    int(p.stem.split("_")[1]) for p in sorted(Path("data/interim/translations").glob("batch_*.psv"))]
failed = False
for n in batches:
    path = Path(f"data/interim/translations/batch_{n:03d}.psv")
    expected = [r["id"] for r in rows[(n - 1) * SIZE:n * SIZE]]
    lines = path.read_text(encoding="utf-8").splitlines()
    got = []
    for i, line in enumerate(lines[1:], 2):
        cols = [c.strip() for c in line.split(" | ")]
        if len(cols) != 4 or not all(cols):
            print(f"{path.name}:{i}: expected 4 non-empty columns: {line!r}")
            failed = True
            continue
        if not CYRILLIC.search(cols[1]) or not CYRILLIC.search(cols[3]):
            print(f"{path.name}:{i}: russian columns without cyrillic: {line!r}")
            failed = True
        got.append(cols[0])
    if got != expected:
        missing = [x for x in expected if x not in got]
        extra = [x for x in got if x not in expected]
        print(f"{path.name}: ids mismatch; missing={missing} extra={extra}")
        failed = True
print("FAIL" if failed else f"ok: {len(batches)} batch(es)")
sys.exit(1 if failed else 0)
