#!/usr/bin/env bash
# Validates AI-twin modules and appends a results table to docs/results.md.
# Usage: scripts/validate-twin.sh first                 # all five, right after generating
#        scripts/validate-twin.sh repair network iam    # only the modules you repaired
set -uo pipefail
ROUND=${1:-first}; shift || true
MODULES=${*:-secure-bucket network iam foundation detection}
OUT=docs/results.md
mkdir -p docs

{
  echo
  echo "## AI twin: terraform validate ($ROUND answer, $(date -u +%F))"
  echo
  echo "| Module | Valid | Errors | Unsupported or invented types/arguments |"
  echo "| --- | --- | --- | --- |"
} >> "$OUT"

for m in $MODULES; do
  dir=ai-twin/modules/$m
  if [ ! -d "$dir" ]; then
    echo "| $m | missing | - | - |" >> "$OUT"; echo "MISSING: $m"; continue
  fi
  if ! terraform -chdir="$dir" init -backend=false -input=false > /dev/null 2>&1; then
    echo "| $m | no | init failed | run init by hand to see why |" >> "$OUT"; echo "INVALID: $m (init)"; continue
  fi
  json=$(terraform -chdir="$dir" validate -json -no-color)
  valid=$(jq -r 'if .valid then "yes" else "no" end' <<< "$json")
  errs=$(jq -r '.error_count' <<< "$json")
  bad=$(jq -r '[.diagnostics[]? | select(.severity=="error")
          | select(.summary|test("Unsupported|Invalid resource type|Invalid data source"))
          | "\(.range.filename // "?"):\(.range.start.line // "?") \(.summary): \(.detail|split("\n")[0])"]
          | unique | join("<br>") | gsub("\\|";"\\|")' <<< "$json")
  rm -f "$dir/.terraform.lock.hcl"   # lock files belong to root configs only
  echo "| $m | $valid | $errs | ${bad:--} |" >> "$OUT"
  [ "$valid" = yes ] && echo "VALID: $m" || echo "INVALID: $m"
done
echo "Appended to $OUT"