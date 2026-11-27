#!/usr/bin/env bash
# Scans human and AI-twin modules with identical settings and prints a Markdown table.
set -euo pipefail
NEUTRAL=tests/fixtures/.checkov-fixtures.yaml   # no skip-path, so ai-twin is scanned too

echo "| Module | Variant | Trivy CRITICAL | Trivy HIGH | Trivy MEDIUM | Trivy LOW | Checkov failed | Checkov skipped (documented) |"
echo "| --- | --- | --- | --- | --- | --- | --- | --- |"

for m in secure-bucket network iam foundation detection; do
  for v in human ai-twin; do
    dir="modules/$m"; [ "$v" = "ai-twin" ] && dir="ai-twin/modules/$m"
    [ -d "$dir" ] || continue

    read -r tc th tm tl < <(trivy config -q -f json --skip-check-update "$dir" | jq -r '
      [.Results[]?.Misconfigurations[]? | select(.Status=="FAIL") | .Severity] as $s |
      [($s|map(select(.=="CRITICAL"))|length), ($s|map(select(.=="HIGH"))|length),
       ($s|map(select(.=="MEDIUM"))|length),   ($s|map(select(.=="LOW"))|length)] | @tsv')

    read -r cf cs < <( (checkov -d "$dir" --config-file "$NEUTRAL" -o json 2>/dev/null || true) | jq -r '
      (if type=="array" then . else [.] end) as $r |
      [($r|map(.summary.failed // 0)|add), ($r|map(.summary.skipped // 0)|add)] | @tsv')

    echo "| $m | $v | $tc | $th | $tm | $tl | $cf | $cs |"
  done
done