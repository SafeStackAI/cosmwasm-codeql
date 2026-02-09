# Phase 2: Baseline E2E Run & Triage

## Context Links
- [Plan overview](./plan.md)
- [Phase 1: Infrastructure](./phase-01-e2e-test-infrastructure.md)
- [FP patterns research](./research/researcher-02-false-positive-patterns.md)

## Overview
- **Priority:** P1
- **Status:** complete (blocked by Phase 1)
- **Description:** Execute all 10 queries against 4 cw-plus targets. Manually triage each finding as TP/FP/TBD. Produce baseline report driving Phases 3-5.

## Key Insights
- cw-plus contracts are well-audited reference implementations; most findings will be FPs or informational
- Expected high-FP queries: UncheckedCosmwasmArithmetic (Uint128 panics on overflow in cw-std>=1.0), UnprotectedExecuteDispatch (multiple match exprs, top-level auth)
- Expected low-FP queries: StorageKeyCollision, UncheckedStorageUnwrap, MissingMigrateAuthorization
- Triage must capture WHY each finding is FP — this drives precision improvements

## Requirements

### Functional
- Run full E2E suite from Phase 1 infrastructure
- For each finding in SARIF output, record: query_id, file, line, snippet, classification (TP/FP/TBD), reason
- Compute per-query metrics: total_findings, TP_count, FP_count, FP_rate
- Identify top FP patterns per query (group by reason)

### Non-Functional
<!-- Updated: Validation Session 1 - E2E is manual only, no committed baselines -->
- Triage documented in `test/e2e/results/baseline-triage.md`
- Machine-readable summary in `test/e2e/results/baseline-metrics.json`
- All E2E results gitignored (manual validation tool, not regression tests)

## Architecture

### Triage Workflow
```
1. Run run-e2e.sh → SARIF + summary.txt
2. For each query with >0 results:
   a. Open SARIF, inspect each finding location
   b. Read source at location (cw-plus code)
   c. Classify: TP (real issue) / FP (safe code flagged) / TBD (needs domain expertise)
   d. Record reason string (e.g., "Uint128 panics on overflow", "auth at execute level")
3. Aggregate metrics per query
4. Write baseline-triage.md and baseline-metrics.json
```

### Expected Finding Categories per Contract

| Contract | Likely findings | Expected dominant category |
|----------|----------------|---------------------------|
| cw20-base | Arithmetic (token math), dispatch auth | Mostly FP (well-audited) |
| cw721-base | Dispatch auth, address validation | Mix TP/FP |
| cw20-staking | Arithmetic (reward calc), auth | Mostly FP |
| cw4-group | Auth (admin operations) | Mix TP/FP |

## Related Code Files
- **Read:** `test/e2e/results/*//*.sarif` (Phase 1 output)
- **Read:** cw-plus source at flagged locations
- **Create:** `test/e2e/results/baseline-triage.md`
- **Create:** `test/e2e/results/baseline-metrics.json`
- **Create:** `test/e2e/expected/*.expected` files

## Implementation Steps

1. Run `test/e2e/run-e2e.sh` — capture all SARIF output
2. Write a helper script `test/e2e/parse-sarif.sh` to extract findings from SARIF into a flat list: `query | file | line | message`
3. For each finding, inspect source code at location:
   - If in `.cargo/` or dependency code: mark FP reason="dependency code"
   - If arithmetic on Uint128 (cosmwasm-std>=1.0): mark FP reason="panic-on-overflow"
   - If dispatch match on non-msg scrutinee: mark FP reason="non-dispatch match"
   - If handler has execute-level auth: mark FP reason="execute-level auth"
   - If intentionally public handler: mark FP reason="intentionally public"
   - If auth via cw-ownable/cw-controllers: mark FP reason="external auth helper"
   - Otherwise: mark TP or TBD with specific reason
4. Compile triage into `baseline-triage.md` with per-query sections
5. Generate `baseline-metrics.json`:
   ```json
   {
     "queries": {
       "cosmwasm/unchecked-cosmwasm-arithmetic": {
         "total": 15, "tp": 0, "fp": 12, "tbd": 3, "fp_rate": 0.80
       }
     }
   }
   ```
6. Document key FP patterns that will drive Phase 3 and 4 improvements

## Todo List
- [ ] Run full E2E suite
- [ ] Write `parse-sarif.sh` helper
- [ ] Triage cw20-base findings
- [ ] Triage cw721-base findings
- [ ] Triage cw20-staking findings
- [ ] Triage cw4-group findings
- [ ] Compute per-query FP metrics
- [ ] Write baseline-triage.md
- [ ] Write baseline-metrics.json
- [ ] Identify top 3 FP patterns per query for Phase 3-4

## Success Criteria
- Every finding has TP/FP/TBD classification with reason
- Per-query FP rates computed
- Clear mapping: FP pattern -> which phase fixes it

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Too many findings to triage manually | Medium | Medium | Prioritize high-FP queries; sample if >50 per query |
| Ambiguous TP/FP classification | Medium | Low | Use TBD category; revisit with domain expert |
| SARIF parsing edge cases | Low | Low | Use jq for reliable JSON parsing |

## Security Considerations
- Triage report may reveal vulnerability patterns in real contracts; keep results gitignored
- Only baseline expected counts (numbers, not details) committed

## Next Steps
- FP patterns from triage feed directly into:
  - Phase 3: Arithmetic query tuning
  - Phase 4: Dispatch query tuning
  - Phase 5: General cross-cutting improvements
