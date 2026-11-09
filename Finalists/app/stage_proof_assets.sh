#!/bin/sh
# Copies exactly two files into app/, then checks no secrets are present. Never prints key values.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
FIN="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$FIN/.." && pwd)"
mkdir -p "$HERE/data" "$HERE/www"
cp "$FIN/data/processed/opportunities.csv" "$HERE/data/opportunities.csv"
cp "$FIN/data/processed/payload.json" "$HERE/data/payload.json"
cp "$REPO/QualifierChallenge/outs/grant-triage-tool.html" "$HERE/www/tool.html"
cp "$FIN/src/tool/matchmaker.html" "$HERE/www/index.html"

fail=0
bad=$(find "$HERE" \( -name 'api_keys.env' -o -name '.Renviron' -o -name '*.env' \) | head -5)
if [ -n "$bad" ]; then echo "FAIL: secret-named file under app/: $bad"; fail=1; fi

KEYFILE="$FIN/api_keys.env"
if [ -f "$KEYFILE" ]; then
  for v in $(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$KEYFILE" | cut -d= -f1); do
    val=$(grep -E "^$v=" "$KEYFILE" | head -1 | cut -d= -f2-)
    [ -z "$val" ] && continue
    if grep -rqF -- "$val" "$HERE"; then echo "FAIL: content of key variable $v found under app/"; fail=1; fi
  done
fi
[ "$fail" -eq 0 ] && echo "staged OK; secret check passed" || exit 1
