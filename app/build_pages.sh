#!/bin/sh
# build_pages.sh: assemble the GitHub Pages site. Replaces the Azure Container App (deploy_azure.sh).
#   <out>/                      qualifier site (QualifierChallenge/docs), URL unchanged
#   <out>/matchmaker/           the Finals tool: index.html (tool/matchmaker.html) + payload.json + feeds/ (Atom, ICS)
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
cp -R "$REPO/QualifierChallenge/docs/." "$OUT/"
cp "$REPO/tool/matchmaker.html" "$OUT/matchmaker/index.html"
cp "$PAYLOAD" "$OUT/matchmaker/payload.json"
python3 "$HERE/build_feeds.py" "$PAYLOAD" "$OUT/matchmaker"
touch "$OUT/.nojekyll"

bad=$(find "$OUT" \( -name 'api_keys.env' -o -name '.Renviron' -o -name '*.env' \) | head -5)
[ -z "$bad" ] || { echo "FAIL: secret-named file in site: $bad"; exit 1; }
echo "site built in $OUT: $(find "$OUT" -type f | wc -l | tr -d ' ') files, payload $(wc -c < "$PAYLOAD" | tr -d ' ') bytes"
