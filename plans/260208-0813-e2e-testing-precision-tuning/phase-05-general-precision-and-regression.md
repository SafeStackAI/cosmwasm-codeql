# Phase 5: General Precision & Regression

## Context Links
- [Plan overview](./plan.md)
- [FP patterns research](./research/researcher-02-false-positive-patterns.md)
- Phase 2 baseline triage (after execution)
- Phase 3 arithmetic delta metrics
- Phase 4 dispatch delta metrics

## Overview
- **Priority:** P2
- **Status:** complete (blocked by Phases 3-4)
- **Description:** Apply cross-cutting precision improvements shared by multiple queries. Run full regression on synthetic fixtures. Run final E2E pass to confirm overall FP reduction. Optionally add Stargaze as Tier 2 target.

## Key Insights
- 7 of 10 queries share the same FP pattern: flagging findings in dependency code (`.cargo/`, `target/`)
- DRY opportunity: extract a reusable `isUserContractCode` predicate into CosmWasm.qll
- All queries already exclude test files; consolidate into shared predicate
- `@precision` annotations control GitHub Code Scanning display — tune per query based on E2E results
- Stargaze launchpad provides multi-contract patterns not seen in cw-plus

## Requirements

### Functional
- Extract shared `isUserContractCode(File f)` predicate into library
- Apply to all 10 queries (replace per-query file exclusion)
- Review + update `@precision` tags based on E2E FP rates
- Run full synthetic regression: all 20 test cases pass
- Run final E2E: confirm aggregate FP rate < 20%
- Optionally: add Stargaze launchpad as Tier 2 E2E target

### Non-Functional
- No new library files; add predicate to existing CosmWasm.qll or new section in Authorization.qll
- Minimal diff to queries — just swap filter clauses for shared predicate

## Architecture

### Shared Predicate: `isUserContractCode`

Add to `src/lib/CosmWasm.qll`:
```ql
/**
 * Holds if `f` is user-written contract code (not dependency, target, or test).
 */
predicate isUserContractCode(File f) {
  not f.getAbsolutePath().matches("%/.cargo/%") and
  not f.getAbsolutePath().matches("%/target/%") and
  not f.getBaseName().matches("%test%.rs")
}
```

### Query Updates (all 10)

Replace per-query test exclusion:
```ql
// Before (each query):
not foo.getLocation().getFile().getBaseName().matches("%test%.rs")

// After:
isUserContractCode(foo.getLocation().getFile())
```

Queries already using dependency exclusion (Phases 3-4) also consolidated.

### Precision Tag Updates (based on E2E results)

| Query | Current | Proposed | Rationale |
|-------|---------|----------|-----------|
| MissingExecuteAuthorization | high | high | Low FP rate expected |
| MissingMigrateAuthorization | high | high | Low FP rate expected |
| UnprotectedExecuteDispatch | medium | medium | Heuristic improved but still medium |
| UncheckedCosmwasmArithmetic | medium | medium | Heuristic query |
| UncheckedStorageUnwrap | high | high | Direct pattern match |
| MissingAddressValidation | medium | medium | Addr::unchecked usage varies |
| StorageKeyCollision | high | high | Exact string match |
| IbcCeiViolation | medium | medium | Broad pattern |
| SubmsgWithoutReplyHandler | high | high | Structural check |
| ReplyHandlerIgnoringErrors | medium | medium | Heuristic |

Note: actual values adjusted after Phase 2 triage data.

## Related Code Files
- **Modify:** `src/lib/CosmWasm.qll` — add `isUserContractCode` predicate
- **Modify:** All 10 queries in `src/queries/` — use shared predicate
- **Modify:** `test/e2e/run-e2e.sh` — optionally add Stargaze target
- **Read:** Phase 2/3/4 metrics for precision tag decisions

## Implementation Steps

1. **Add `isUserContractCode` to CosmWasm.qll:**
   - Define predicate checking file path exclusions
   - Place after existing imports at bottom of file

2. **Update all 10 queries to use shared predicate:**
   - Replace `not X.getLocation().getFile().getBaseName().matches("%test%.rs")` with `isUserContractCode(X.getLocation().getFile())`
   - Remove any per-query `.cargo/` and `/target/` exclusions added in Phases 3-4 (now in shared predicate)
   - Queries to update:
     - `access-control/MissingExecuteAuthorization.ql`
     - `access-control/MissingMigrateAuthorization.ql`
     - `access-control/UnprotectedExecuteDispatch.ql`
     - `data-safety/UncheckedCosmwasmArithmetic.ql`
     - `data-safety/UncheckedStorageUnwrap.ql`
     - `data-safety/MissingAddressValidation.ql`
     - `data-safety/StorageKeyCollision.ql`
     - `cross-contract/IbcCeiViolation.ql`
     - `cross-contract/SubmsgWithoutReplyHandler.ql`
     - `cross-contract/ReplyHandlerIgnoringErrors.ql`

3. **Update `@precision` tags** based on Phase 2 triage FP rates (adjust table above)

4. **Run synthetic regression:**
   ```bash
   test/run-tests.sh
   ```
   All 20 tests (10 vulnerable + 10 safe) must pass with unchanged expected counts.

5. **Run final E2E:**
   ```bash
   test/e2e/run-e2e.sh
   ```
   Compare against Phase 2 baseline. Compute final FP rates.

6. **Optionally add Stargaze Tier 2 target:**
   - Add to `run-e2e.sh` config: `public-awesome/launchpad` repo
   - Target contracts: `sg-721`, `base-minter`, `vending-minter`
   - Build DBs, run queries, triage new findings
   - Create `test/e2e/expected/sg-721.expected` etc.

7. **Write final metrics report:**
   - Before/after FP rates per query
   - Total findings reduced
   - Any remaining known FP patterns documented as future work
   - Save to `test/e2e/results/final-metrics.md`

## Todo List
- [ ] Add `isUserContractCode` predicate to CosmWasm.qll
- [ ] Update all 10 queries to use shared predicate
- [ ] Run synthetic regression — all 20 pass
- [ ] Review and update `@precision` tags
- [ ] Run final E2E pass
- [ ] Compare final vs baseline FP rates
<!-- Updated: Validation Session 1 - No committed baselines; E2E manual only -->
- [ ] (Optional) Add Stargaze Tier 2 targets
- [ ] Write final metrics report

## Success Criteria
- All 20 synthetic tests pass (zero regression)
- Aggregate E2E FP rate across all queries < 20%
- Each query uses shared `isUserContractCode` predicate (DRY)
- `@precision` tags reflect measured FP rates
- Final metrics report documents before/after improvements

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `getAbsolutePath()` unavailable on File class | Low | High | Verify API; fallback to `getRelativePath()` or `toString()` |
| Shared predicate changes affect synthetic test counts | Low | Medium | Test immediately after adding predicate |
| Stargaze repo structure incompatible | Medium | Low | Tier 2 is optional; skip if problematic |
| Final FP rate still > 20% | Medium | Medium | Document remaining FP patterns as future work |

## Security Considerations
- Excluding dependency code could miss supply-chain vulnerabilities in vendored deps
- Mitigated: most CosmWasm projects use `crates.io` deps not vendored; `.cargo/registry` is standard
- Document limitation: query only scans user contract code by default

## Next Steps
- After Phase 5 completion: update project roadmap and changelog
- Future work candidates:
  - Version-gated arithmetic query (detect cosmwasm-std version from Cargo.toml)
  - Inline suppression comment support (`// codeql[query-id]`)
  - Confidence tiers per finding (high/medium/low)
  - Stargaze + DAO DAO as permanent E2E targets
