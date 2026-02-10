#!/bin/bash
# CosmWasm CodeQL E2E Test Runner (multi-target)
# Reads targets from targets.conf, clones repos, builds CodeQL DBs, runs all queries.
# Outputs per-target SARIF files + summary tables + aggregate report.
#
# Usage:
#   ./test/e2e/run-e2e.sh                        # Run all targets (cached DBs)
#   ./test/e2e/run-e2e.sh --target cw-plus       # Run single target
#   ./test/e2e/run-e2e.sh --rebuild               # Rebuild all DBs
#   ./test/e2e/run-e2e.sh --rebuild cw-plus       # Rebuild specific target DB
#
# Requirements: codeql CLI, git, jq
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGETS_DIR="$SCRIPT_DIR/targets"
DB_DIR="$SCRIPT_DIR/db"
RESULTS_DIR="$SCRIPT_DIR/results"
TARGETS_CONF="$SCRIPT_DIR/targets.conf"

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

# --- Parse CLI arguments ---
TARGET_FILTER=""
REBUILD_TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_FILTER="$2"; shift 2 ;;
    --rebuild)
      if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
        REBUILD_TARGET="$2"; shift 2
      else
        REBUILD_TARGET="ALL"; shift
      fi ;;
    *) shift ;;
  esac
done

# --- Read targets from conf ---
read_targets() {
  local targets=()
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    targets+=("$line")
  done < "$TARGETS_CONF"
  printf '%s\n' "${targets[@]}"
}

# --- Clone or use cached repo ---
clone_target() {
  local name="$1" repo="$2" ref="$3"
  local target_dir="$TARGETS_DIR/$name"

  if [ -d "$target_dir" ]; then
    echo "  Using cached clone: $target_dir"
  else
    echo "  Cloning $name..."
    if ! git clone --depth 50 "$repo" "$target_dir" 2>&1 | tail -1; then
      echo "  $(red FAIL) Failed to clone $name from $repo"
      return 1
    fi
    cd "$target_dir"
    if ! git checkout "$ref" 2>&1 | tail -1; then
      echo "  $(red FAIL) Failed to checkout $ref for $name"
      cd "$SCRIPT_DIR"
      return 1
    fi
    cd "$SCRIPT_DIR"
    echo "  $(green OK) $name cloned at $ref"
  fi
}

# --- Build CodeQL database ---
build_db() {
  local name="$1" source_filter="$2"
  local target_dir="$TARGETS_DIR/$name"
  local db_path="$DB_DIR/${name}-db"
  local should_rebuild="false"

  if [ "$REBUILD_TARGET" = "ALL" ] || [ "$REBUILD_TARGET" = "$name" ]; then
    should_rebuild="true"
  fi

  if [ -d "$db_path" ] && [ "$should_rebuild" != "true" ]; then
    echo "  Using cached database: $db_path"
  else
    echo "  Building CodeQL database for $name..."
    echo "    (This may take several minutes)"
    rm -rf "$db_path"

    # Use source-root scoping; full workspace by default
    local source_root="$target_dir"

    codeql database create "$db_path" \
      --language=rust \
      --source-root="$source_root" \
      --overwrite \
      2>&1 | tail -5
    echo "  $(green OK) Database created: $db_path"
  fi
}

# --- Run queries against a target ---
run_queries() {
  local name="$1"
  local db_path="$DB_DIR/${name}-db"
  local target_results="$RESULTS_DIR/$name"
  mkdir -p "$target_results"

  local summary_file="$target_results/summary.txt"
  echo "CosmWasm CodeQL E2E Results — $(date)" > "$summary_file"
  echo "Target: $name" >> "$summary_file"
  echo "" >> "$summary_file"
  printf "%-45s %s\n" "Query" "Results" >> "$summary_file"
  printf "%-45s %s\n" "-----" "-------" >> "$summary_file"

  local target_total=0

  for query in "${QUERIES[@]}"; do
    local qname
    qname=$(basename "$query" .ql)
    local sarif_file="$target_results/${qname}.sarif"

    echo -n "  Running $qname..."
    codeql database analyze \
      --additional-packs="$PROJECT_ROOT" \
      --format=sarifv2.1.0 \
      --output="$sarif_file" \
      --rerun \
      -- "$db_path" "$PROJECT_ROOT/$query" \
      2>&1 | tail -1

    local count=0
    if [ -f "$sarif_file" ]; then
      count=$(jq '[.runs[].results[]] | length' "$sarif_file" 2>/dev/null || echo 0)
    fi

    target_total=$((target_total + count))

    if [ "$count" -gt 0 ]; then
      echo " $(yellow "$count findings")"
    else
      echo " $(green "0 findings")"
    fi

    printf "%-45s %s\n" "$qname" "$count" >> "$summary_file"
  done

  echo "" >> "$summary_file"
  echo "Total findings: $target_total" >> "$summary_file"

  echo "  Total: $target_total findings"
  # Return total via global
  _TARGET_TOTAL=$target_total
}

# --- Main ---
echo "=== CosmWasm CodeQL E2E Runner ==="
echo ""

mkdir -p "$TARGETS_DIR" "$DB_DIR" "$RESULTS_DIR"

GRAND_TOTAL=0
TARGET_COUNT=0
AGGREGATE_FILE="$RESULTS_DIR/aggregate-summary.txt"
echo "CosmWasm CodeQL Aggregate E2E Results — $(date)" > "$AGGREGATE_FILE"
echo "" >> "$AGGREGATE_FILE"
printf "%-15s %-45s %s\n" "Target" "Query" "Findings" >> "$AGGREGATE_FILE"
printf "%-15s %-45s %s\n" "------" "-----" "--------" >> "$AGGREGATE_FILE"

while IFS='|' read -r name repo ref source_filter; do
  # Apply target filter if set
  if [ -n "$TARGET_FILTER" ] && [ "$name" != "$TARGET_FILTER" ]; then
    continue
  fi

  echo "--- Target: $name (ref: $ref) ---"
  TARGET_COUNT=$((TARGET_COUNT + 1))

  clone_target "$name" "$repo" "$ref"
  build_db "$name" "$source_filter"

  echo ""
  echo "  Running queries on $name..."
  run_queries "$name"

  GRAND_TOTAL=$((GRAND_TOTAL + _TARGET_TOTAL))

  # Append per-query counts to aggregate
  local_results="$RESULTS_DIR/$name"
  for query in "${QUERIES[@]}"; do
    qname=$(basename "$query" .ql)
    sarif_file="$local_results/${qname}.sarif"
    count=0
    if [ -f "$sarif_file" ]; then
      count=$(jq '[.runs[].results[]] | length' "$sarif_file" 2>/dev/null || echo 0)
    fi
    printf "%-15s %-45s %s\n" "$name" "$qname" "$count" >> "$AGGREGATE_FILE"
  done

  echo ""
done < <(read_targets)

echo "" >> "$AGGREGATE_FILE"
echo "Targets: $TARGET_COUNT | Grand total: $GRAND_TOTAL findings" >> "$AGGREGATE_FILE"

# --- Print aggregate ---
echo "=== Aggregate Summary ==="
cat "$AGGREGATE_FILE"
echo ""
echo "Per-target results: $RESULTS_DIR/<target>/summary.txt"
echo "Aggregate:          $AGGREGATE_FILE"
