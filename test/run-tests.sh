#!/bin/bash
# CosmWasm CodeQL Query Test Runner
# Creates databases from fixtures and verifies query results.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_DIR="$SCRIPT_DIR/db"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
REBUILD="${1:-}"

PASS=0
FAIL=0

green() { printf "\033[32m%s\033[0m" "$1"; }
red() { printf "\033[31m%s\033[0m" "$1"; }

count_results() {
  local output="$1"
  # Count lines starting with | (header line + data rows; separator starts with +)
  local total_pipe_lines
  total_pipe_lines=$(echo "$output" | grep -c "^|" || true)
  # Subtract 1 for the header row. Separator (+---+) doesn't start with |.
  if [ "$total_pipe_lines" -le 1 ]; then
    echo 0
  else
    echo $((total_pipe_lines - 1))
  fi
}

run_query() {
  local db="$1" query="$2"
  codeql query run \
    --database="$db" \
    --additional-packs="$PROJECT_ROOT" \
    "$PROJECT_ROOT/$query" 2>&1
}

echo "=== CosmWasm CodeQL Test Runner ==="
echo ""

# Step 1: Build databases
mkdir -p "$DB_DIR"
for fixture in vulnerable-contract safe-contract; do
  db_path="$DB_DIR/${fixture}-db"
  if [ -d "$db_path" ] && [ "$REBUILD" != "--rebuild" ]; then
    echo "Using cached database: $db_path"
  else
    echo "Building database: $fixture ..."
    codeql database create "$db_path" \
      --language=rust \
      --source-root="$FIXTURES_DIR/$fixture" \
      --overwrite \
      2>&1 | tail -1
  fi
done
echo ""

# Step 2: Define tests as "query_path:expected_vuln_count"
TESTS=(
  "src/queries/access-control/MissingExecuteAuthorization.ql:2"
  "src/queries/access-control/MissingMigrateAuthorization.ql:1"
  "src/queries/access-control/UnprotectedExecuteDispatch.ql:2"
  "src/queries/data-safety/UncheckedCosmwasmArithmetic.ql:1"
  "src/queries/data-safety/UncheckedStorageUnwrap.ql:1"
  "src/queries/data-safety/MissingAddressValidation.ql:1"
  "src/queries/data-safety/StorageKeyCollision.ql:1"
  "src/queries/cross-contract/IbcCeiViolation.ql:1"
  "src/queries/cross-contract/SubmsgWithoutReplyHandler.ql:1"
  "src/queries/cross-contract/ReplyHandlerIgnoringErrors.ql:0"
)

echo "--- Vulnerable Contract Tests ---"
for test_spec in "${TESTS[@]}"; do
  query="${test_spec%%:*}"
  expected="${test_spec##*:}"
  name=$(basename "$query" .ql)

  output=$(run_query "$DB_DIR/vulnerable-contract-db" "$query")
  actual=$(count_results "$output")

  if [ "$actual" -eq "$expected" ]; then
    echo "  $(green PASS) $name: $actual results (expected $expected)"
    PASS=$((PASS + 1))
  else
    echo "  $(red FAIL) $name: $actual results (expected $expected)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "--- Safe Contract Tests (expect 0 results each) ---"
for test_spec in "${TESTS[@]}"; do
  query="${test_spec%%:*}"
  name=$(basename "$query" .ql)

  output=$(run_query "$DB_DIR/safe-contract-db" "$query")
  actual=$(count_results "$output")

  if [ "$actual" -eq 0 ]; then
    echo "  $(green PASS) $name: 0 results"
    PASS=$((PASS + 1))
  else
    echo "  $(red FAIL) $name: $actual results (expected 0)"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "=== Results: $(green "$PASS passed"), $(red "$FAIL failed") ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
