#!/usr/bin/env python3
"""Fail if matchmaker.html declares the same function name twice at the top level of one script block
(the later one silently wins). Nested helpers with the same name in different functions are allowed.
Usage: python3 app/check_dupes.py [path]   (default: tool/matchmaker.html)"""
import re, sys, collections, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
p = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / "tool/matchmaker.html"
seen = collections.defaultdict(list); block = 0
for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
    if "<script" in line: block += 1
    m = re.match(r"^( {2}|)(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(", line)
    if m: seen[(block, m.group(2))].append(i)
bad = {k: v for k, v in seen.items() if len(v) > 1}
for (blk, name), lines in sorted(bad.items()): print(f"DUPLICATE function {name} (script block {blk}) at lines {lines}")
print("ok: no duplicate function names" if not bad else f"FAIL: {len(bad)} duplicate name(s)")
sys.exit(1 if bad else 0)
