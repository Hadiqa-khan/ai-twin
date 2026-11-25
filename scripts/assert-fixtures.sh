#!/usr/bin/env bash
# Fails unless each scanner reports the specific rule IDs expected for each broken fixture.
# In CI, trivy comes from the Trivy baseline step above this one (trivy-action puts it on PATH).
set -euo pipefail
cd "$(dirname "$0")/.."
CF=tests/fixtures/.checkov-fixtures.yaml
TRIVY_WANT="0.76.2"
TMP=$(mktemp -d)

command -v trivy >/dev/null || { echo "trivy not found: the Trivy step must run before this script"; exit 1; }
trivy --version | grep -q "Version: $TRIVY_WANT" || { echo "Expected Trivy $TRIVY_WANT, got: $(trivy --version | head -1)"; exit 1; }

for f in public-bucket wildcard-iam; do
  # --skip-check-update: use the rules embedded in this Trivy version, so results don't change between runs
  trivy config -q -f json --skip-check-update "tests/fixtures/$f" \
    | jq -r '.Results[]?.Misconfigurations[]? | select(.Status=="FAIL") | .ID' | sort -u > "$TMP/trivy-$f"
  (checkov -d "tests/fixtures/$f" --config-file "$CF" -o json || true) \
    | jq -r '(if type=="array" then . else [.] end)[] | .results.failed_checks[]?.check_id' | sort -u > "$TMP/checkov-$f"
done

expect() {  # label, file, expected IDs...
  local label=$1 file=$2; shift 2
  for id in "$@"; do
    grep -qx "$id" "$file" || { echo "MISSING: $label did not report $id"; exit 1; }
  done
  echo "OK: $label reported $*"
}

# public-bucket: the four Block Public Access settings are switched off
expect "Trivy public-bucket"   "$TMP/trivy-public-bucket"   AWS-0086 AWS-0087 AWS-0091 AWS-0093
expect "Checkov public-bucket" "$TMP/checkov-public-bucket" CKV_AWS_53 CKV_AWS_54 CKV_AWS_55 CKV_AWS_56 CKV2_AWS_6
# wildcard-iam: Action "*" on Resource "*" (full admin)
expect "Checkov wildcard-iam"  "$TMP/checkov-wildcard-iam"  CKV_AWS_62 CKV_AWS_63

# Known gap (docs/exceptions.md): Trivy reports nothing for wildcard-iam. If that changes, promote it to a real gate.
if [ -s "$TMP/trivy-wildcard-iam" ]; then
  echo "CHANGED: Trivy now reports $(tr '\n' ' ' < "$TMP/trivy-wildcard-iam")for wildcard-iam. Add these IDs as a gate above."
  exit 1
fi

echo "Both scanners rejected the deliberately broken code."