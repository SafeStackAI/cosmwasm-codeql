# Phase 1: E2E Test Infrastructure

## Context Links
- [Plan overview](./plan.md)
- [Real-world targets research](./research/researcher-01-real-world-targets.md)
- [Existing test runner](../../test/run-tests.sh)

## Overview
- **Priority:** P1
- **Status:** complete
- **Description:** Create `test/e2e/` directory with scripts to clone real-world contracts, build CodeQL databases, and run all 10 queries producing SARIF + summary output.

## Key Insights
- Existing `test/run-tests.sh` provides proven pattern: build DB, run queries, count results
- cw-plus is a Cargo workspace; CodeQL Rust extractor handles workspaces but may need `--source-root` pointing at individual contract dirs
- Database creation is expensive (~2-5min per contract); caching is essential
- SARIF output enables GitHub code scanning integration and structured FP analysis

## Requirements

### Functional
- Clone cw-plus repo (pin to specific commit for reproducibility)
- Build CodeQL databases for 4 target contracts: cw20-base, cw721-base, cw20-staking, cw4-group
- Run all 10 queries against each database
- Output SARIF files per query-per-target
- Generate summary table: query x target x result_count
- Support `--rebuild` flag to force database recreation

### Non-Functional
- Cache databases in `test/e2e/db/` (gitignored)
- Clone targets into `test/e2e/targets/` (gitignored)
- Script should be runnable standalone and in CI
- Total runtime < 30min for full suite

## Architecture

<!-- Updated: Validation Session 1 - Single workspace DB instead of per-contract DBs; no committed expected files -->
```
test/e2e/
  run-e2e.sh          # Main orchestrator script
  targets/             # Cloned repos (gitignored)
    cw-plus/           # CosmWasm/cw-plus at pinned commit
  db/                  # CodeQL databases (gitignored)
    cw-plus-db/        # Single workspace database
  results/             # SARIF output + summary (gitignored)
    MissingExecuteAuthorization.sarif
    ...
    summary.txt
```

## Related Code Files
- **Create:** `test/e2e/run-e2e.sh` - main E2E runner
- **Modify:** `.gitignore` - add `test/e2e/targets/`, `test/e2e/db/`, `test/e2e/results/`

## Implementation Steps

1. Create `test/e2e/` directory structure
2. Write `run-e2e.sh` with these sections:
   a. **Config block:** pin cw-plus repo URL + commit hash, list target contracts with source-root paths relative to workspace
   b. **Clone step:** `git clone --depth 1` if `targets/cw-plus` missing; `git checkout <commit>` for reproducibility
   c. **DB build step:** `codeql database create` with `--source-root=targets/cw-plus` and `--language=rust` for single workspace DB. Skip if cached + no `--rebuild`
   d. **Query run step:** For each query, `codeql database analyze` with `--format=sarifv2.1.0` output to `results/<query>.sarif`. Also run `codeql query run` for human-readable table output
   e. **Summary step:** Parse SARIF files, count results per query, print summary table to stdout + `results/summary.txt`
3. Update `.gitignore` with e2e artifact dirs
4. Test script locally: verify clone, DB build, query execution for at least cw20-base
5. Document usage in script header comments

### Database Build Strategy for cw-plus Workspace
<!-- Updated: Validation Session 1 - Single workspace DB confirmed -->
- cw-plus uses a Cargo workspace with `contracts/` subdirectories
- Build single database with `--source-root=targets/cw-plus` (workspace root)
- All contracts extracted into one DB; triage filters results by file path per contract
- If workspace extraction fails, fallback to `--source-root=targets/cw-plus/contracts/cw20-base` for individual contracts

## Todo List
- [ ] Create `test/e2e/` directory
- [ ] Write `run-e2e.sh` config + clone logic
- [ ] Write single workspace DB creation with caching
- [ ] Write query execution + SARIF output loop
- [ ] Write summary table generator
- [ ] Update `.gitignore`
- [ ] Test workspace DB build end-to-end locally
- [ ] Verify all 10 queries run against workspace DB

## Success Criteria
- `run-e2e.sh` runs without errors against cw-plus workspace DB
- SARIF files produced for each query-target combination (40 files)
- Summary table printed showing result counts
- Second run uses cached DBs (fast)
- Script works from clean clone (no pre-existing state)

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CodeQL Rust extractor fails on workspace | Medium | High | Use per-contract source-root; fallback to cargo check -p |
| cw-plus dependencies fail to resolve | Low | Medium | Use `--no-build` + `--language=rust` (source-only extraction) |
| Database build timeout in CI | Medium | Medium | Cache DBs as CI artifacts; set generous timeout |
| cw-plus repo unavailable | Low | Low | Pin commit hash; mirror if needed |

## Security Considerations
- Only clone public repos; no auth tokens needed
- No execution of contract code; CodeQL does static analysis only
- SARIF output may contain file paths; gitignore results dir

## Next Steps
- After infrastructure works, proceed to Phase 2: run baseline and triage findings
