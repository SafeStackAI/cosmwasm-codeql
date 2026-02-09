# Phase 4: Dispatch Precision Tuning

## Context Links
- [Plan overview](./plan.md)
- [FP patterns research](./research/researcher-02-false-positive-patterns.md)
- [UnprotectedExecuteDispatch.ql](../../src/queries/access-control/UnprotectedExecuteDispatch.ql)
- [MissingExecuteAuthorization.ql](../../src/queries/access-control/MissingExecuteAuthorization.ql)
- [Authorization.qll](../../src/lib/Authorization.qll)
- [Messages.qll](../../src/lib/Messages.qll)

## Overview
- **Priority:** P1
- **Status:** complete (blocked by Phase 2)
- **Description:** Reduce FPs in dispatch-related queries by: (A) narrowing `ExecuteDispatch` to msg-scrutinee matches only, (B) checking execute-level auth in addition to handler-level, (C) expanding auth helper pattern recognition.

## Key Insights
- `ExecuteDispatch` = ANY match expr inside execute() — catches non-dispatch matches (config lookups, state checks)
- Fix: scrutinee must reference the `msg` parameter (last param of execute fn)
- Top-level auth pattern: `if info.sender != admin { return Err(...) }` before dispatch — query only checks handler functions
- cw-ownable `assert_owner(deps.storage, &info.sender)?` not matched by current auth patterns
- cw-controllers `is_admin()`, `can_execute()` also unrecognized
- Intentionally public handlers (Claim, Withdraw) are valid design; reduce severity for these

## Requirements

### Functional
- `ExecuteDispatch` must require match scrutinee to reference execute()'s msg parameter
- `UnprotectedExecuteDispatch.ql` must also check if execute() itself has auth checks (not just handler)
- `Authorization.qll` must recognize: `assert_owner`, `is_admin`, `can_execute`, `check_permission`, `validate_sender`
- Add dependency path exclusion (same as Phase 3)

### Non-Functional
- Synthetic tests must pass (vulnerable-contract=2 for dispatch, safe-contract=0)
- Changes to Authorization.qll affect MissingExecuteAuthorization.ql too — verify no regression

## Architecture

### A. Fix ExecuteDispatch in Messages.qll

Current:
```ql
class ExecuteDispatch extends MatchExpr {
  ExecuteDispatch() {
    exists(ExecuteHandler handler |
      this.getEnclosingCallable() = handler
    )
  }
}
```

Proposed — require scrutinee references msg param:
```ql
class ExecuteDispatch extends MatchExpr {
  ExecuteDispatch() {
    exists(ExecuteHandler handler |
      this.getEnclosingCallable() = handler and
      (
        // Scrutinee directly references the last parameter (msg)
        this.getScrutinee().toString().matches("%" +
          handler.getParam(handler.getNumberOfParams() - 1).getName().getText() + "%")
        or
        // Fallback: scrutinee contains "msg" (common naming)
        this.getScrutinee().toString().regexpMatch(".*\\bmsg\\b.*")
      )
    )
  }
}
```

### B. Add execute-level auth check to UnprotectedExecuteDispatch.ql

Add condition: also check if the enclosing execute handler itself has auth:
```ql
not hasAuthorizationCheck(dispatch.getEnclosingCallable())
```
This catches the pattern where auth is at execute() level before the match dispatch.

### C. Expand Authorization.qll auth helpers

Add to the "Call to auth helper function" section:
```ql
name.matches("%assert_owner%") or    // cw-ownable
name.matches("%is_admin%") or        // cw-controllers
name.matches("%can_execute%") or     // cw-controllers
name.matches("%check_permission%") or
name.matches("%validate_sender%") or
name.matches("%assert_admin%")
```

Also add method call pattern for cw-ownable (it's a method, not free function):
```ql
// cw-ownable / cw-controllers method calls
exists(MethodCallExpr call |
  call.getEnclosingCallable() = f and
  (
    call.getIdentifier().toString().matches("%assert_owner%") or
    call.getIdentifier().toString().matches("%is_admin%") or
    call.getIdentifier().toString().matches("%can_execute%") or
    call.getIdentifier().toString().matches("%assert_admin%")
  )
)
```

## Related Code Files
- **Modify:** `src/lib/Messages.qll` — tighten `ExecuteDispatch` scrutinee check
- **Modify:** `src/lib/Authorization.qll` — expand auth helper patterns (CallExpr + MethodCallExpr sections)
- **Modify:** `src/queries/access-control/UnprotectedExecuteDispatch.ql` — add execute-level auth check + dependency path exclusion

## Implementation Steps

1. **Modify `Messages.qll` — tighten ExecuteDispatch:**
   - Add scrutinee check requiring reference to msg parameter or "msg" substring
   - Keep existing `getEnclosingCallable() = handler` check

2. **Modify `Authorization.qll` — expand auth helpers in CallExpr section:**
   - Add `assert_owner`, `is_admin`, `can_execute`, `check_permission`, `validate_sender`, `assert_admin` to the CallExpr name patterns
   - Add new MethodCallExpr clause for the same names (cw-ownable uses method syntax)

3. **Modify `UnprotectedExecuteDispatch.ql`:**
   - Add execute-level auth check:
     ```ql
     not hasAuthorizationCheck(dispatch.getEnclosingCallable())
     ```
     Insert before existing `not hasAuthorizationCheck(target)` — if execute() itself has auth, skip all arms
   - Add dependency path exclusion:
     ```ql
     not arm.getLocation().getFile().getAbsolutePath().matches("%/.cargo/%") and
     not arm.getLocation().getFile().getAbsolutePath().matches("%/target/%")
     ```

4. **Run synthetic tests:** `test/run-tests.sh`
   - Verify UnprotectedExecuteDispatch: vulnerable=2, safe=0
   - Verify MissingExecuteAuthorization: vulnerable=2, safe=0
   - Verify MissingMigrateAuthorization: vulnerable=1, safe=0

5. **Run E2E:** compare dispatch query results against Phase 2 baseline

6. **Document delta:** record FP reduction per target

### Scrutinee Detection Detail

In CodeQL Rust, `MatchExpr.getScrutinee()` returns the expression being matched. For `match msg { ... }`, scrutinee is a `PathExpr` or `NameRef` for `msg`. We use `toString()` matching since the exact AST type varies:
- Direct: `match msg { ... }` → scrutinee.toString() = "msg"
- Field access: `match msg.action { ... }` → scrutinee.toString() contains "msg"
- Method: `match msg.into() { ... }` → scrutinee.toString() contains "msg"

The fallback regex `\bmsg\b` handles common naming. If the parameter is named differently (e.g., `execute_msg`), the first branch catches it via param name lookup.

## Todo List
- [ ] Tighten `ExecuteDispatch` in Messages.qll — add scrutinee check
- [ ] Expand auth helpers in Authorization.qll — add 6 new patterns
- [ ] Add MethodCallExpr auth detection in Authorization.qll
- [ ] Add execute-level auth check in UnprotectedExecuteDispatch.ql
- [ ] Add dependency path exclusion in UnprotectedExecuteDispatch.ql
- [ ] Run synthetic tests — verify all 3 access-control queries pass
- [ ] Run E2E — measure FP reduction
- [ ] Verify MissingExecuteAuthorization not regressed by Authorization.qll changes

## Success Criteria
- All 3 access-control synthetic tests pass (unchanged expected counts)
- E2E FP rate for UnprotectedExecuteDispatch drops to <25%
- cw-ownable `assert_owner` pattern recognized as auth check
- Non-dispatch match expressions no longer flagged
- No false negatives introduced (vulnerable-contract detection unchanged)

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Scrutinee check too strict — misses valid dispatch | Medium | High | Fallback regex on "msg" + test on real contracts |
| `getScrutinee()` API unavailable or different name | Low | High | Check CodeQL Rust AST docs; may be `getExpr()` instead |
| Auth expansion creates false negatives | Low | Medium | Only adds more patterns; doesn't remove existing checks |
| Execute-level auth check hides real issues | Low | Medium | Auth at execute level IS a valid auth pattern |

## Security Considerations
- Expanding auth recognition could mask cases where "assert_owner" exists but doesn't actually check sender
- Mitigated: current heuristic matches method NAME not behavior; same limitation as existing patterns
- Document that query checks for auth pattern presence, not semantic correctness

## Next Steps
- Phase 5: apply cross-cutting improvements (file exclusion predicate, final regression + E2E pass)
