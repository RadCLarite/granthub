#!/usr/bin/env bash
# Build the clean judge snapshot: tracked files only, no .git, no api_keys.env.
# Usage (from anywhere inside the repo):  Finalists/app/make_snapshot.sh [OUT_DIR]
# Default OUT_DIR: <repo>/../ffm-snapshot.  Also writes OUT_DIR.zip. Reads HEAD, changes nothing in the repo.
# Does not publish anything. Hand the folder or zip to Kent.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
OUT="${1:-$ROOT/../ffm-snapshot}"
cd "$ROOT"

rm -rf "$OUT" "$OUT.zip"; mkdir -p "$OUT"

# Tracked files at HEAD only (so .RData, .Renviron, .git never come along).
git archive HEAD -- . \
  ':(exclude)Finalists/api_keys.env' \
  ':(exclude)Finalists/_team' \
  ':(exclude).claude' ':(exclude)Finalists/.claude' \
  ':(exclude)comms' \
  ':(exclude)Finalists/graphify-out' ':(exclude)Finalists/stale' \
  | tar -x -C "$OUT"

# Placeholder so a developer knows what to create.
cat > "$OUT/Finalists/api_keys.env.example" <<'EX'
# Make your own free keys, then save this file as api_keys.env (never commit it).
# 00_config.R loads it with readRenviron().
SIMPLER_GRANTS_KEY=
SAM_API_KEY=
EX

# Tell the reader up front.
{ printf '> **Judge snapshot.** `api_keys.env` is deliberately not included. To rerun anything that calls\n> Grants.gov or SAM.gov, make your own free keys and copy `Finalists/api_keys.env.example` to `Finalists/api_keys.env`.\n> Cached data is included. Checked Sat Nov 7 on a snapshot with no keys: from `Finalists/src`, `Rscript R/10_run_ranking.R`,\n> then `Rscript tests/run_tests.R` (84 of 84) and `Rscript R/check_facts.R` (49 of 49); `R/11_build_payload.R` rebuilt payload.json byte-identical.\n\n'; cat "$OUT/README.md"; } > "$OUT/README.md.new" && mv "$OUT/README.md.new" "$OUT/README.md"

# Scan: no key value, key file or .git may be present. Values are never printed.
fail=0
if [ -f Finalists/api_keys.env ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue;; esac
    [ -n "$v" ] || continue
    if grep -rqF -- "$v" "$OUT"; then echo "FAIL: value of $k found in snapshot"; fail=1; fi
  done < Finalists/api_keys.env
fi
for bad in .git .RData .Renviron api_keys.env everett_api_keys.md stale graphify-out; do
  if find "$OUT" -name "$bad" | grep -q .; then echo "FAIL: $bad present"; fail=1; fi
done
[ $fail -eq 0 ] || { echo "Snapshot NOT safe. Removing."; rm -rf "$OUT"; exit 1; }

(cd "$(dirname "$OUT")" && zip -qr "$(basename "$OUT").zip" "$(basename "$OUT")")
echo "OK: $OUT  ($(find "$OUT" -type f | wc -l | tr -d ' ') files, $(du -sh "$OUT" | cut -f1)); zip: $OUT.zip"
