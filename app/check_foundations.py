#!/usr/bin/env python3
"""check_foundations.py: build-time gate for the researcher tab's foundation list. Stdlib only.
Usage: python3 app/check_foundations.py <foundations.csv> <research_foundations.json>
Fails (exit 1, one line per problem) when a CSV row has no name, focus, https url or strict YYYY-MM-DD verified_on
date (not in the future), when an id repeats, or when the JSON does not list exactly the CSV's ids (rebuild it with
Rscript R/15_build_foundations.R). The same rules as validate_foundations() in R/helpers_research.R, for CI and deploys
that have no R. FOUNDATIONS_TODAY (YYYY-MM-DD) overrides today for tests."""
import csv, datetime as dt, json, os, re, sys

csv_path, json_path = sys.argv[1], sys.argv[2]
today = os.environ.get("FOUNDATIONS_TODAY") or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
errs = []
rows = list(csv.DictReader(open(csv_path, encoding="utf-8-sig", newline="")))
need = ["id", "name", "focus", "url", "verified_on"]
seen = set()
for i, r in enumerate(rows, 1):
    for col in need:
        if not (r.get(col) or "").strip():
            errs.append("row %d: %s is empty" % (i, col))
    url = (r.get("url") or "").strip()
    if url and not url.startswith("https://"):
        errs.append("row %d: url must start with https://" % i)
    v = (r.get("verified_on") or "").strip()
    if v:
        ok = re.fullmatch(r"\d{4}-\d{2}-\d{2}", v) is not None
        if ok:
            try:
                dt.date.fromisoformat(v)
            except ValueError:
                ok = False
        if not ok:
            errs.append("row %d: verified_on is not a YYYY-MM-DD date" % i)
        elif v > today:
            errs.append("row %d: verified_on is after %s" % (i, today))
    rid = (r.get("id") or "").strip()
    if rid in seen:
        errs.append("row %d: duplicate id %s" % (i, rid))
    seen.add(rid)
payload = json.load(open(json_path, encoding="utf-8"))
if sorted(str(x.get("id")) for x in payload.get("rows", [])) != sorted(seen - {""}):
    errs.append("research_foundations.json does not match foundations.csv: run Rscript R/15_build_foundations.R and commit the result")
if errs:
    print("foundations check FAILED:\n  " + "\n  ".join(errs), file=sys.stderr)
    sys.exit(1)
print("foundations ok: %d rows" % len(rows))
