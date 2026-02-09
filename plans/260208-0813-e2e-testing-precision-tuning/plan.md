---
title: "E2E Testing & Precision Tuning for CosmWasm CodeQL"
description: "Test all 10 queries against real-world contracts and tune precision to reduce false positives"
status: complete
priority: P1
effort: 12h
branch: main
tags: [testing, precision, e2e, codeql]
created: 2026-02-08
---

# E2E Testing & Precision Tuning

## Goal
Validate 10 CodeQL queries against production CosmWasm contracts; reduce false positives via targeted precision improvements.

## Phases

| # | Phase | Effort | Status |
|---|-------|--------|--------|
| 1 | [E2E Test Infrastructure](./phase-01-e2e-test-infrastructure.md) | 2h | complete |
| 2 | [Baseline E2E Run & Triage](./phase-02-baseline-e2e-run.md) | 3h | complete |
| 3 | [Arithmetic Precision Tuning](./phase-03-arithmetic-precision-tuning.md) | 2h | complete |
| 4 | [Dispatch Precision Tuning](./phase-04-dispatch-precision-tuning.md) | 3h | complete |
| 5 | [General Precision & Regression](./phase-05-general-precision-and-regression.md) | 2h | complete |

## Dependencies
- CodeQL CLI installed locally
- `codeql/rust-all` extractor available
- Internet access to clone target repos

## Key Research
- [Real-world targets](./research/researcher-01-real-world-targets.md) - cw-plus (primary), Stargaze (stretch)
- [FP patterns](./research/researcher-02-false-positive-patterns.md) - arithmetic cosmwasm-std>=1.0, dispatch multi-match, auth helper gaps

## Success Criteria
- All 10 queries run against cw-plus contracts (cw20, cw721, cw20-staking, cw4-group)
- Each finding manually categorized as TP/FP/TBD
- FP rate on tuned queries < 20% (down from estimated ~40-50%)
- Existing synthetic tests still pass (regression)

## Risks
- CodeQL Rust extractor may not handle workspace Cargo.toml (cw-plus is a workspace)
- Real contracts may use macro-heavy patterns not visible in extracted AST
- Database creation time for large repos could be significant

## Validation Log

### Session 1 — 2026-02-08
**Trigger:** Initial plan creation validation
**Questions asked:** 7

#### Questions & Answers

1. **[Architecture]** The plan targets cw-plus contracts (cw20-base, cw721-base, cw20-staking, cw4-group). Should we build one CodeQL database per contract subdirectory, or one database for the entire cw-plus workspace?
   - Options: Per-contract databases (Recommended) | Single workspace database | Both — workspace + per-contract
   - **Answer:** Single workspace database
   - **Rationale:** One DB for entire cw-plus workspace captures cross-crate references and simplifies infrastructure. Phase 1 script builds 1 DB instead of 4, reducing build time and complexity. Results filtered per-contract by file path during triage.

2. **[Assumptions]** cosmwasm-std >= 1.0 Uint128 arithmetic panics on overflow (already safe). How should the arithmetic query handle this?
   - Options: Add metadata note only (Recommended) | Disable by default, opt-in | Remove Uint128 matching entirely
   - **Answer:** Add metadata note only
   - **Rationale:** Query stays active for older cosmwasm-std versions and custom integer types. Updated @description documents the >= 1.0 behavior so users can make informed decisions. No code logic change needed.

3. **[Tradeoffs]** For dispatch detection: should we require the match scrutinee to reference the `msg` parameter, or use a looser heuristic?
   - Options: Strict msg-param reference (Recommended) | Loose 'msg' substring match | Keep current (any match in execute)
   - **Answer:** Strict msg-param reference
   - **Rationale:** Eliminates false positives from non-dispatch match expressions (config state checks, etc.). Risk of missing renamed params mitigated by fallback to "msg" substring. Directly addresses the highest-FP pattern in dispatch detection.

4. **[Scope]** Phase 2 requires triaging every finding as TP/FP/TBD. Given E2E may produce 50-100+ findings across 4 contracts, how should we approach triage?
   - Options: Full manual triage (Recommended) | Sample triage per query | Auto-classify known patterns
   - **Answer:** Full manual triage
   - **Rationale:** Precise FP rates enable confident precision tuning in Phases 3-4. Every finding classified ensures no blind spots. Worth the 2-3h investment for data-driven query improvement.

5. **[Architecture]** The shared `isUserContractCode` predicate excludes `.cargo/` and `target/` dirs. Should it also exclude common generated/macro-expanded files?
   - Options: Only .cargo/ and target/ (Recommended) | Also exclude build.rs and proc-macro crates | Exclude everything outside contracts/ dir
   - **Answer:** Only .cargo/ and target/
   - **Rationale:** Conservative exclusion avoids over-filtering. Macro-expanded code is user-relevant and may contain real vulnerabilities. Whitelist approach too aggressive — would break on non-cw-plus project structures.

6. **[Scope]** After tuning, should we commit the E2E expected baselines (result counts per query per contract) as regression tests?
   - Options: Yes, commit baselines (Recommended) | No, E2E is manual only | Commit as CI-optional
   - **Answer:** No, E2E is manual only
   - **Rationale:** E2E serves as a manual validation tool, not an automated regression gate. Avoids maintenance burden of updating baselines when cw-plus evolves. Synthetic tests remain the stable regression suite.

7. **[Tradeoffs]** What's the acceptable FP rate threshold for declaring the tuning phase complete?
   - Options: <30% aggregate FP rate | <20% aggregate FP rate (Recommended) | <10% aggregate FP rate
   - **Answer:** <20% aggregate FP rate
   - **Rationale:** Ambitious but signals production quality. Achievable with the planned 3-layer arithmetic filter + dispatch scrutinee fix + expanded auth patterns. Documented as target in success criteria.

#### Confirmed Decisions
- **DB strategy:** Single workspace database for cw-plus (not per-contract)
- **Arithmetic query:** Metadata note only, keep query active
- **Dispatch fix:** Strict msg-param reference with fallback
- **Triage approach:** Full manual triage of all findings
- **File filter:** Conservative — only .cargo/ and target/
- **E2E baselines:** Manual only, not committed
- **FP target:** <20% aggregate

#### Action Items
- [ ] Phase 1: Rewrite DB build to create single workspace DB instead of 4 per-contract DBs
- [ ] Phase 1: Remove per-contract expected files; use single results set filtered by file path
- [ ] Phase 2: Remove baseline-metrics.json and expected/*.expected file creation (manual only)
- [ ] Phase 4: Use strict msg-param reference for scrutinee (confirmed)

#### Impact on Phases
- Phase 1: Major change — single workspace DB instead of 4 per-contract DBs. Simplifies run-e2e.sh config, DB build loop, and results structure. Remove per-contract expected files.
- Phase 2: Minor change — remove committed expected baselines. Triage report is still created but not committed as regression test.
- Phase 4: Confirmed — strict msg-param scrutinee approach proceeds as planned.
- Phase 5: Minor change — remove step to update expected baseline files. Final metrics report remains.
