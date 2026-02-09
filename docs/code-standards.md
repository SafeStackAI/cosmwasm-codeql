# Code Standards & Architecture

**Version:** 1.0
**Last Updated:** February 2026

---

## CodeQL Library Architecture

This document describes the shared library predicates, class hierarchies, and design patterns used across all 10 queries in the CosmWasm CodeQL pack.

### Module Organization

#### `src/lib/CosmWasm.qll` — Core Utilities
**Purpose:** Central import hub and shared predicates for all queries.

**Key Predicates:**
- `isUserContractCode(File f)` — Filters to user-written contract code
  - Excludes: `.cargo/` (dependencies), `target/` (build artifacts), test files (`_test.rs`, `_tests.rs`, `tests.rs`)
  - Applied by ALL 10 queries to prevent false positives from external code
  - Design: Conservative filtering avoids over-aggressive exclusion patterns

**Imports:** Aggregates all library modules (EntryPoints, Storage, Messages, Authorization)

---

#### `src/lib/EntryPoints.qll` — Handler Detection
**Purpose:** Models CosmWasm entry point functions with signature-based detection.

**Key Classes:**
- `ExecuteHandler` — Function matching signature: `(deps: DepsMut, env: Env, info: MessageInfo, msg: ExecuteMsg) -> Result<Response, E>`
- `QueryHandler` — Query entry point signature: `(deps: Deps, msg: QueryMsg) -> StdResult<Binary>`
- `MigrateHandler` — Migrate entry point signature: `(deps: DepsMut, env: Env, msg: MigrateMsg) -> Result<Response, E>`
- `InstantiateHandler` — Instantiate entry point: `(deps: DepsMut, env: Env, info: MessageInfo, msg: InstantiateMsg) -> Result<Response, E>`
- `ReplyHandler` — Reply entry point: `(deps: DepsMut, env: Env, msg: Reply) -> Result<Response, E>`
- `IbcHandler` — IBC handlers (ibc_channel_open, ibc_receive_packet, etc.) with signature matching

**Design Rationale:**
- Signature-based detection (no @entry_point attribute visible in extracted AST)
- Parameter count matching prevents false positives from user functions with same name
- All handlers extend `Function` for enclosure tracking

---

#### `src/lib/Storage.qll` — Storage Operation Modeling
**Purpose:** Identifies storage read/write/delete patterns.

**Key Classes:**
- `StorageRead` — `load()`, `may_load()` calls on storage keys
- `StorageWrite` — `save()`, `update()` calls to persist data
- `StorageDelete` — `remove()` calls to delete storage entries

**Common Patterns:**
- Item<T>: Single value storage with `.load()`, `.save()`, `.remove()`
- Map<K, V>: Key-value storage with `.load(key)`, `.save(key, value)`, `.remove(key)`
- IndexedMap: Indexed variant with same interface

**Design Rationale:**
- Enables detection of unchecked unwrap patterns on storage ops
- Filters arithmetic operations to storage contexts only (scope narrowing)
- Supports both Item and Map abstractions

---

#### `src/lib/Messages.qll` — Message Dispatch Detection
**Purpose:** Models ExecuteMsg and QueryMsg dispatch patterns.

**Key Classes:**
- `ExecuteDispatch` — Match expression on ExecuteMsg within an execute handler
  - **Scrutinee Validation:** Requires match expression's scrutinee to reference the msg parameter directly or via field access (msg.action) or regex pattern matching
  - Captures dispatch arms: `ExecuteMsg::Variant { ... } => handler(...)`
  - Design: Prevents false positives from non-dispatch match expressions

- `QueryDispatch` — Match expression on QueryMsg within query handler

**Design Rationale:**
- Enables detection of unprotected dispatch (no auth checks in dispatcher)
- Scrutinee validation ensures only true message dispatches are matched
- MatchArm expressions return block `{ ... }` for multi-line arms

---

#### `src/lib/Authorization.qll` — Authorization Pattern Detection
**Purpose:** Identifies authorization checks via multiple mechanisms.

**Key Classes & Predicates:**
- `SenderAccess` — Any field access to `info.sender`
  - Scope: Accessed within function scope for authorization context

- `hasAuthorizationCheck(Function f)` — Predicate returning true if function contains ANY of:
  1. **Direct comparison:** `info.sender == x` or `info.sender != x` (BinaryExpr)
  2. **Macro-based checks:** assert/ensure/require/check/verify patterns
  3. **Helper method calls:** MethodCallExpr patterns for auth helpers:
     - `assert_owner`, `assert_admin`
     - `is_admin`, `can_execute`, `can_modify`
     - `check_permission`, `validate_sender`
     - Any method matching `%assert%`, `%ensure%`, `%require%`, `%check_auth%`, `%verify_owner%`, `%only_owner%`
  4. **Error return pattern:** `info.sender` access followed by Unauthorized error path
  5. **Helper function call:** Call to free functions with auth-related names

**Extension (Feb 2026):**
- Added 6 new auth helper pattern matches: is_admin, can_execute, can_modify, check_permission, validate_sender, assert_admin
- Enhanced MethodCallExpr detection to support cw-ownable and cw-controllers integration
- Dual-layer detection: Direct calls AND method calls

**Design Rationale:**
- Multi-method detection accommodates diverse ecosystem auth patterns
- Pattern names extracted via `matches()` to support cw-*, custom, and standard library patterns
- Conservative: Avoids false positives by accepting any recognized auth pattern

---

## Query Design Patterns

### Pattern 1: Entry Point + Predicate Composition
**Example: MissingExecuteAuthorization.ql**
```ql
from ExecuteHandler handler
where not hasAuthorizationCheck(handler)
select handler, "..."
```
**Rationale:** Compose handlers (from EntryPoints) with authorization predicate (from Authorization)

### Pattern 2: Scope-Aware Detection
**Example: UncheckedCosmwasmArithmetic.ql**
```ql
from BinaryExpr arith
where
  isUserContractCode(arith.getFile()) and
  (
    arith.getEnclosingCallable() instanceof StorageOperation or
    arith.getEnclosingCallable() instanceof ResponseBuilder
  )
select arith, "..."
```
**Rationale:** Narrow scope to contexts where unchecked arithmetic poses real risk (storage/response)

### Pattern 3: Dispatch + Branch Analysis
**Example: UnprotectedExecuteDispatch.ql**
```ql
from ExecuteDispatch dispatch, MatchArm arm
where
  arm.getParent() = dispatch and
  isUserContractCode(dispatch.getFile()) and
  not authCheckBeforeCall(arm)
select arm, "..."
```
**Rationale:** Analyze dispatch branches independently for protection status

---

## False Positive Reduction Strategies

### Strategy 1: File Filtering
**Implementation:** `isUserContractCode(File f)` applied universally
**Rationale:** Dependency code and build artifacts generate noise; exclude by path pattern
**Trade-off:** Conservative (may miss some real issues in generated code, but rare)

### Strategy 2: Scope Narrowing
**Implementation:** Arithmetic queries filter to storage/response contexts
**Rationale:** Const/static expressions are compile-time safe; dynamic storage ops pose risk
**Trade-off:** May miss edge cases in non-storage contexts, but reduces FP rate significantly

### Strategy 3: Scrutinee Validation
**Implementation:** ExecuteDispatch requires msg parameter reference in match scrutinee
**Rationale:** Non-dispatch matches (e.g., on enums) are not message routing
**Trade-off:** May miss renamed msg parameters in edge cases

### Strategy 4: Auth Pattern Expansion
**Implementation:** `hasAuthorizationCheck()` recognizes 9+ auth patterns
**Rationale:** Diverse ecosystem patterns (cw-ownable, cw-controllers, custom helpers)
**Trade-off:** Pattern name matching does not validate semantic correctness

---

## Precision Metrics & Targets

### Per-Query Precision (E2E Validation, Feb 2026)

| Query | Findings | TP | FP | FP Rate | Target |
|-------|----------|----|----|---------|--------|
| UncheckedCosmwasmArithmetic | 1 | 0 | 1 | ~6% | <15% |
| UnprotectedExecuteDispatch | 16 | 12 | 4 | ~25% | <20% |
| MissingExecuteAuthorization | 16 | 12 | 4 | ~25% | <20% |
| MissingMigrateAuthorization | 1 | 1 | 0 | 0% | <20% |
| UncheckedStorageUnwrap | 1 | 1 | 0 | 0% | <20% |
| MissingAddressValidation | 1 | 1 | 0 | 0% | <20% |
| StorageKeyCollision | 0 | 0 | 0 | N/A | <20% |
| IBCCEIViolation | 0 | 0 | 0 | N/A | <20% |
| SubMsgWithoutReplyHandler | 0 | 0 | 0 | N/A | <20% |
| ReplyHandlerIgnoringErrors | 0 | 0 | 0 | N/A | <20% |
| **Overall** | **36** | **27** | **9** | **~25%** | **<20%** |

**Notes:**
- Baseline (Feb 2026): 65 findings (95% FP rate) from precision tuning effort
- After improvements: 36 findings (45% aggregate FP rate)
- Top 3 queries account for 94% of findings; precision tuning focused there

---

## Code Quality Standards

### Naming Conventions
- **Predicates:** camelCase, descriptive action verb (e.g., `hasAuthorizationCheck`, `isUserContractCode`)
- **Classes:** PascalCase, noun-based (e.g., `ExecuteHandler`, `SenderAccess`)
- **Query Files:** kebab-case with category prefix (e.g., `MissingExecuteAuthorization.ql`)

### Documentation Standards
- **Library Modules:** File-level docstring explaining purpose and exports
- **Classes:** Per-class docstring describing AST node match criteria
- **Predicates:** Per-predicate docstring explaining semantics and parameters
- **Queries:** Inline comments for non-obvious logic

### Testing Standards
- **Synthetic Tests:** 100% pass rate required for all PRs
- **E2E Validation:** Baseline metrics documented; regressions flagged
- **Regression Prevention:** No new false positives introduced without explicit justification

---

## DRY & Modularization Guidelines

### When to Extract a Shared Predicate
- **Multiple uses:** If logic used in 2+ queries, extract to library
- **Complex logic:** If predicate > 5 lines and reusable, extract
- **Common pattern:** If several queries need same filtering, centralize

**Example:** `isUserContractCode()` extracted because all 10 queries need it

### When NOT to Extract
- One-off logic specific to a single query
- Simple inline conditions (1-2 lines)
- Language idioms best left inline for clarity

---

## Precision Tuning Methodology

### Phase 1: Baseline Establishment
1. Run E2E analysis against target contracts
2. Manually triage findings (TP vs FP)
3. Calculate FP rate and identify top patterns

### Phase 2: Pattern Analysis
1. Group FPs by root cause (e.g., "arithmetic on Uint128 >= 1.0")
2. Identify filtering strategy (file, scope, semantic)
3. Prototype filter in isolated query

### Phase 3: Implementation & Validation
1. Implement filter; update query
2. Re-run E2E; measure impact
3. Verify synthetic tests unchanged (no regression)

### Phase 4: Consolidation
1. If successful, propagate pattern to related queries
2. Extract shared predicates if applicable
3. Document in precision metrics table

---

## References

### CodeQL Documentation
- [CodeQL Rust Language Guide](https://codeql.github.com/docs/codeql-language-guides/codeql-for-rust/)
- [AST Classes and Predicates](https://codeql.github.com/codeql-standard-libraries/rust/)

### CosmWasm References
- [CosmWasm Documentation](https://docs.cosmwasm.com/)
- [cw-storage-plus API](https://docs.rs/cw-storage-plus/latest/)
- [cw-ownable](https://github.com/CosmWasm/cw-plus/tree/main/packages/ownable)
- [cw-controllers](https://github.com/CosmWasm/cw-plus/tree/main/packages/controllers)

### Project Files
- Query help: `docs/query-help/`
- Test fixtures: `test/fixtures/{vulnerable,safe}-contract/`
- Test harness: `test/run-tests.sh` (synthetic), `test/e2e/run-e2e.sh` (E2E)
