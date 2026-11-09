#!/bin/sh
# build_pages.sh: assemble the GitHub Pages site. Replaces the Azure Container App (deploy_azure.sh).
#   <out>/                      landing page (app/site_index.html) that forwards to matchmaker/
#   <out>/matchmaker/           the tool: index.html (tool/matchmaker.html) + payload.json + feeds/ (Atom, ICS)
#   <out>/matchmaker/research/  researcher tab: research_tab.js, research_core.js, research.css, synonyms.json, research.json
# Usage: sh app/build_pages.sh <out_dir> [payload.json]
# The payload is the daily-job output when given (see app/job.R), else the tracked data/processed/payload.json.
# Checks the payload shape and that no secret-named file ends up in the site. Never prints key values.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
OUT="${1:?usage: build_pages.sh <out_dir> [payload.json]}"
PAYLOAD="${2:-$REPO/data/processed/payload.json}"

[ -f "$PAYLOAD" ] || { echo "FAIL: no payload at $PAYLOAD"; exit 1; }
grep -q '"agencies"' "$PAYLOAD" && grep -q '"data_as_of"' "$PAYLOAD" || { echo "FAIL: payload lacks agencies or data_as_of"; exit 1; }

mkdir -p "$OUT/matchmaker"
cp "$HERE/site_index.html" "$OUT/index.html"
cp "$REPO/tool/matchmaker.html" "$OUT/matchmaker/index.html"
cp "$PAYLOAD" "$OUT/matchmaker/payload.json"
# researcher tab: scripts, styles, synonyms and the research payload (served from matchmaker/research/)
RESEARCH="$REPO/data/processed/research.json"
[ -f "$RESEARCH" ] || { echo "FAIL: no research payload at $RESEARCH"; exit 1; }
grep -q '"rows"' "$RESEARCH" && grep -q '"as_of"' "$RESEARCH" || { echo "FAIL: research.json lacks rows or as_of"; exit 1; }
mkdir -p "$OUT/matchmaker/research"
cp "$REPO"/tool/research/* "$OUT/matchmaker/research/"
cp "$RESEARCH" "$OUT/matchmaker/research/research.json"
[ -f "$OUT/matchmaker/research/research_tab.js" ] && [ -f "$OUT/matchmaker/research/synonyms.json" ] || { echo "FAIL: research files missing from site"; exit 1; }
python3 "$HERE/build_feeds.py" "$PAYLOAD" "$OUT/matchmaker"
touch "$OUT/.nojekyll"

bad=$(find "$OUT" \( -name 'api_keys.env' -o -name '.Renviron' -o -name '*.env' \) | head -5)
[ -z "$bad" ] || { echo "FAIL: secret-named file in site: $bad"; exit 1; }
echo "site built in $OUT: $(find "$OUT" -type f | wc -l | tr -d ' ') files, payload $(wc -c < "$PAYLOAD" | tr -d ' ') bytes, research files $(ls "$OUT/matchmaker/research" | wc -l | tr -d ' ')"
