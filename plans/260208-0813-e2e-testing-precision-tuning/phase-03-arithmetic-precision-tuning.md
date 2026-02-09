# Phase 3: Arithmetic Precision Tuning

## Context Links
- [Plan overview](./plan.md)
- [FP patterns research](./research/researcher-02-false-positive-patterns.md)
- [Current query](../../src/queries/data-safety/UncheckedCosmwasmArithmetic.ql)
- Phase 2 baseline triage (after execution)

## Overview
- **Priority:** P1
- **Status:** complete (blocked by Phase 2)
- **Description:** Reduce FP rate of `UncheckedCosmwasmArithmetic.ql` from estimated ~60-80% to <20% by adding file path filters, scope narrowing, and metadata improvements.

## Key Insights
- cosmwasm-std >= 1.0: `Uint128` ops (`+`,`-`,`*`) **panic on overflow** via trait impls — already safe
- Heuristic name matching (`amount`, `total`, `balance`) catches pagination vars, loop counters, non-financial code
- Dependency code (`.cargo/registry/`, `target/`) fires on library internals — not user code
- Const/static expressions are compile-time; cannot overflow at runtime
- CVE-2024-58263 only affects cosmwasm-std < 1.0 (wrapping math default)

## Requirements

### Functional
- Exclude findings in dependency directories (`.cargo/`, `target/`)
- Exclude arithmetic inside const/static items
- Narrow scope: only flag arithmetic in functions that interact with storage OR return Response
- Update query metadata: add note about cosmwasm-std >= 1.0 panic semantics
- Consider reducing `@problem.severity` from `warning` to `recommendation`

### Non-Functional
- Existing synthetic test (vulnerable-contract expects 1 result) must still pass
- Changes must be backward-compatible with CodeQL SARIF consumers

## Architecture

### Current Query Logic
```
BinaryArithmeticOperation arith WHERE:
  operator in ["+", "-", "*"]
  AND operand matches financial name heuristic OR Uint128/Uint256
  AND NOT matches checked_* pattern
  AND NOT in test file
```

### Proposed Query Logic (additions in **bold**)
```
BinaryArithmeticOperation arith WHERE:
  operator in ["+", "-", "*"]
  AND operand matches financial name heuristic OR Uint128/Uint256
  AND NOT matches checked_* pattern
  AND NOT in test file
  AND **NOT in dependency path (.cargo/, target/)**
  AND **NOT inside const/static item**
  AND **enclosing function has storage write OR returns Response type**
```

### Specific CodeQL Predicates to Add

**1. File path exclusion:**
```ql
not arith.getLocation().getFile().getAbsolutePath().matches("%/.cargo/%")
and
not arith.getLocation().getFile().getAbsolutePath().matches("%/target/%")
```

**2. Const/static exclusion — approach:**
Check if the enclosing callable is a `ConstExpr` or if there's no enclosing function (top-level static). In CodeQL Rust, const items don't have enclosing functions with params:
```ql
exists(Function f |
  arith.getEnclosingCallable() = f and
  f.getNumberOfParams() > 0
)
```
This ensures arithmetic is inside a real function, not a const/static initializer.

**3. Scope narrowing (storage or Response context):**
```ql
exists(Function f |
  arith.getEnclosingCallable() = f and
  (
    hasStorageWrite(f) or
    hasStorageRead(f) or
    f.getRetType().toString().matches("%Response%")
  )
)
```
This limits findings to functions that interact with contract state or produce responses — the financial-risk surface.

## Related Code Files
- **Modify:** `src/queries/data-safety/UncheckedCosmwasmArithmetic.ql` — add 3 filter conditions + update metadata
- **Read:** `src/lib/Storage.qll` — reuse `hasStorageWrite`/`hasStorageRead` predicates
- **Modify:** `src/queries/data-safety/UncheckedCosmwasmArithmetic.ql` — add `import src.lib.CosmWasm`

## Implementation Steps

1. **Add CosmWasm import** to UncheckedCosmwasmArithmetic.ql:
   ```ql
   import src.lib.CosmWasm
   ```

2. **Add dependency path exclusion** to WHERE clause:
   ```ql
   not arith.getLocation().getFile().getAbsolutePath().matches("%/.cargo/%") and
   not arith.getLocation().getFile().getAbsolutePath().matches("%/target/%")
   ```

3. **Add const/static exclusion** — require enclosing function with params:
   ```ql
   exists(Function f |
     arith.getEnclosingCallable() = f and
     f.getNumberOfParams() > 0
   )
   ```

4. **Add scope narrowing** — require storage interaction or Response return:
   ```ql
   exists(Function f |
     arith.getEnclosingCallable() = f and
     (hasStorageWrite(f) or hasStorageRead(f) or
      f.getRetType().toString().matches("%Response%"))
   )
   ```
   Note: combine steps 3+4 into a single `exists(Function f | ...)` block.

5. **Update metadata:**
   - Change `@description` to add: "Note: cosmwasm-std >= 1.0 Uint128 ops panic on overflow. This query targets contracts that may use older versions or custom integer types."
   - Keep `@precision medium` (heuristic query)
   - Keep `@problem.severity warning`

6. **Run synthetic tests:** `test/run-tests.sh` — verify vulnerable-contract still produces 1 result, safe-contract produces 0

7. **Run E2E:** `test/e2e/run-e2e.sh` — compare finding counts against Phase 2 baseline

8. **Document delta:** Record how many FPs eliminated per target contract

## Todo List
- [ ] Add `import src.lib.CosmWasm` to query
- [ ] Add dependency path exclusion filter
- [ ] Add const/static exclusion (require enclosing function)
- [ ] Add storage/Response scope narrowing
- [ ] Update query description metadata
- [ ] Run synthetic tests — verify regression pass
- [ ] Run E2E — measure FP reduction
- [ ] Document before/after metrics

## Success Criteria
- Synthetic tests pass: vulnerable-contract=1, safe-contract=0
- E2E FP rate for this query drops to <30% (from estimated 60-80%)
- No true positives lost (no new false negatives)
- Query still detects unchecked arithmetic in vulnerable-contract fixture

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Scope narrowing too aggressive (false negatives) | Medium | High | Test against vulnerable-contract first; verify TP preserved |
| `getRetType().toString()` unreliable for Response | Medium | Medium | Test on real contracts; may need `matches("%Result%")` too |
| Const exclusion removes non-const findings | Low | Medium | The `getNumberOfParams() > 0` check is conservative |
| `getAbsolutePath()` not available on File | Low | High | Verify API; fallback to `getRelativePath()` or `toString()` |

## Security Considerations
- Reducing scope could hide real vulnerabilities in edge cases
- Mitigated by: keeping query as `medium` precision, documenting limitations, recommending manual review for cosmwasm-std version

## Next Steps
- Phase 4: Apply similar precision improvements to dispatch detection
- Metrics from this phase inform whether additional arithmetic tuning needed in Phase 5
