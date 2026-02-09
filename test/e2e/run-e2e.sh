#!/bin/bash
# CosmWasm CodeQL E2E Test Runner
# Clones real-world contracts, builds CodeQL database, runs all 10 queries.
# Outputs SARIF files + summary table.
#
# Usage:
#   ./test/e2e/run-e2e.sh              # Use cached DB if available
#   ./test/e2e/run-e2e.sh --rebuild    # Force rebuild DB
#
# Requirements: codeql CLI, git, jq
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGETS_DIR="$SCRIPT_DIR/targets"
DB_DIR="$SCRIPT_DIR/db"
RESULTS_DIR="$SCRIPT_DIR/results"
REBUILD="${1:-}"

# --- Config: pinned cw-plus workspace ---
CW_PLUS_REPO="https://github.com/CosmWasm/cw-plus.git"
CW_PLUS_COMMIT="v2.0.0"  # tag for reproducibility
CW_PLUS_DIR="$TARGETS_DIR/cw-plus"
CW_PLUS_DB="$DB_DIR/cw-plus-db"

# Target contracts (for filtering results during triage)
TARGET_CONTRACTS=(
  "contracts/cw20-base"
  "contracts/cw721-base"
  "contracts/cw20-staking"
  "contracts/cw4-group"
)

# All 10 queries
QUERIES=(
  "src/queries/access-control/MissingExecuteAuthorization.ql"
  "src/queries/access-control/MissingMigrateAuthorization.ql"
  "src/queries/access-control/UnprotectedExecuteDispatch.ql"
  "src/queries/data-safety/UncheckedCosmwasmArithmetic.ql"
  "src/queries/data-safety/UncheckedStorageUnwrap.ql"
  "src/queries/data-safety/MissingAddressValidation.ql"
  "src/queries/data-safety/StorageKeyCollision.ql"
  "src/queries/cross-contract/IbcCeiViolation.ql"
  "src/queries/cross-contract/SubmsgWithoutReplyHandler.ql"
  "src/queries/cross-contract/ReplyHandlerIgnoringErrors.ql"
)

green() { printf "\033[32m%s\033[0m" "$1"; }
red() { printf "\033[31m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }

# --- Step 1: Clone cw-plus ---
echo "=== CosmWasm CodeQL E2E Runner ==="
echo ""

mkdir -p "$TARGETS_DIR" "$DB_DIR" "$RESULTS_DIR"

if [ -d "$CW_PLUS_DIR" ]; then
  echo "Using cached cw-plus clone: $CW_PLUS_DIR"
else
  echo "Cloning cw-plus..."
  git clone --depth 50 "$CW_PLUS_REPO" "$CW_PLUS_DIR" 2>&1 | tail -1
  cd "$CW_PLUS_DIR"
  git checkout "$CW_PLUS_COMMIT" 2>&1 | tail -1
  cd "$SCRIPT_DIR"
  echo "  $(green OK) cw-plus cloned at $CW_PLUS_COMMIT"
fi

# --- Step 2: Build CodeQL database (single workspace DB) ---
echo ""
if [ -d "$CW_PLUS_DB" ] && [ "$REBUILD" != "--rebuild" ]; then
  echo "Using cached database: $CW_PLUS_DB"
else
  echo "Building CodeQL database for cw-plus workspace..."
  echo "  (This may take several minutes)"
  rm -rf "$CW_PLUS_DB"
  codeql database create "$CW_PLUS_DB" \
    --language=rust \
    --source-root="$CW_PLUS_DIR" \
    --overwrite \
    2>&1 | tail -5
  echo "  $(green OK) Database created: $CW_PLUS_DB"
fi

# --- Step 3: Run all queries ---
echo ""
echo "--- Running Queries ---"

SUMMARY_FILE="$RESULTS_DIR/summary.txt"
echo "CosmWasm CodeQL E2E Results — $(date)" > "$SUMMARY_FILE"
echo "Target: cw-plus @ $CW_PLUS_COMMIT" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
printf "%-45s %s\n" "Query" "Results" >> "$SUMMARY_FILE"
printf "%-45s %s\n" "-----" "-------" >> "$SUMMARY_FILE"

TOTAL_FINDINGS=0

for query in "${QUERIES[@]}"; do
  name=$(basename "$query" .ql)
  sarif_file="$RESULTS_DIR/${name}.sarif"

  # Run query with SARIF output
  echo -n "  Running $name..."
  codeql database analyze \
    --additional-packs="$PROJECT_ROOT" \
    --format=sarifv2.1.0 \
    --output="$sarif_file" \
    --rerun \
    -- "$CW_PLUS_DB" "$PROJECT_ROOT/$query" \
    2>&1 | tail -1

  # Count results from SARIF
  if [ -f "$sarif_file" ]; then
    count=$(jq '[.runs[].results[]] | length' "$sarif_file" 2>/dev/null || echo 0)
  else
    count=0
  fi

  TOTAL_FINDINGS=$((TOTAL_FINDINGS + count))

  if [ "$count" -gt 0 ]; then
    echo " $(yellow "$count findings")"
  else
    echo " $(green "0 findings")"
  fi

  printf "%-45s %s\n" "$name" "$count" >> "$SUMMARY_FILE"
done

echo "" >> "$SUMMARY_FILE"
echo "Total findings: $TOTAL_FINDINGS" >> "$SUMMARY_FILE"

# --- Step 4: Print summary ---
echo ""
echo "=== Summary ==="
cat "$SUMMARY_FILE"
echo ""
echo "SARIF files: $RESULTS_DIR/*.sarif"
echo "Summary:     $SUMMARY_FILE"
