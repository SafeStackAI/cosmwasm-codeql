#!/bin/bash
# Parse SARIF files into a flat findings list for triage.
# Usage: ./parse-sarif.sh [results-dir]
# Output: query | file | line | message (tab-separated)
set -eo pipefail

RESULTS_DIR="${1:-$(cd "$(dirname "$0")" && pwd)/results}"

for sarif in "$RESULTS_DIR"/*.sarif; do
  [ -f "$sarif" ] || continue
  query_name=$(basename "$sarif" .sarif)

  jq -r --arg q "$query_name" '
    .runs[].results[] |
    .locations[0].physicalLocation as $loc |
    [$q,
     ($loc.artifactLocation.uri // "unknown"),
     ($loc.region.startLine // 0 | tostring),
     (.message.text // "no message")] |
    @tsv
  ' "$sarif" 2>/dev/null || true
done
