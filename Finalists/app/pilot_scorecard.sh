#!/bin/sh
# pilot_scorecard.sh: the pilot's built-in measure. Reads the Pursue / Maybe / Skip marks that grantHub sends to the
# team's feedback log (type "mark": agency, grant, rank, mark, a random browser code; no personal data) and prints,
# by agency, how many Top 10 grants people marked and what share they kept (Pursue or Maybe).
# Team only: needs az login to the team subscription (same access as read_feedback.sh).
#   sh app/pilot_scorecard.sh              # recent container log (last ~300 lines)
#   sh app/pilot_scorecard.sh history      # Log Analytics, past 30 days
#   sh app/pilot_scorecard.sh file LOG.txt # any saved log text (lines containing FEEDBACK ... {json})
# The last mark per browser and grant counts; a mark set back to "none" is dropped.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
  file) src=$(cat "$2") ;;
  history)
    WS=32fe4ead-138c-41fe-b1e7-9559d53b1de1
    src=$(az monitor log-analytics query -w "$WS" --analytics-query "ContainerAppConsoleLogs_CL | where TimeGenerated > ago(30d) | where Log_s has 'FEEDBACK ' and Log_s has 'mark' | order by TimeGenerated asc | project Log_s" -o tsv) ;;
  *) src=$(sh "$HERE/read_feedback.sh") ;;
esac
printf '%s\n' "$src" | python3 -I -c '
import sys, json, re, collections
last = {}
for line in sys.stdin:
    m = re.search(r"\{.*\}", line)
    if not m or "FEEDBACK" not in line: continue
    try: d = json.loads(m.group(0))
    except ValueError: continue
    if d.get("type") != "mark": continue
    last[(d.get("b"), d.get("ag"), d.get("opp"))] = d
by = collections.defaultdict(lambda: {"n": 0, "keep": 0, "browsers": set()})
for (b, ag, opp), d in last.items():
    if d.get("mark") in (None, "none") or not d.get("top10"): continue
    a = by[ag]; a["n"] += 1; a["browsers"].add(b)
    if d.get("mark") in ("Pursue", "Maybe"): a["keep"] += 1
if not by:
    print("No Top 10 marks in this log yet."); sys.exit(0)
print("agency   top10_marked  kept(Pursue/Maybe)  hit_rate  browsers")
tn = tk = 0
for ag in sorted(by):
    a = by[ag]; tn += a["n"]; tk += a["keep"]
    print("%-8s %12d %19d %8.0f%% %9d" % (ag, a["n"], a["keep"], 100.0 * a["keep"] / a["n"], len(a["browsers"])))
print("%-8s %12d %19d %8.0f%%" % ("ALL", tn, tk, 100.0 * tk / tn))
'
