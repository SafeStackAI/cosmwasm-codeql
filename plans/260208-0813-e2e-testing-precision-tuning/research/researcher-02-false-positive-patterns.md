# False Positive Patterns & Precision Tuning Research

**Date:** 2026-02-08

## 1. Arithmetic Heuristic False Positives

### Current Approach
Matches `+`/`-`/`*` where operand name contains: amount, balance, total, supply, price, quantity, reward, stake, fee, deposit, withdraw, or Uint128/Uint256.

### Known FP Sources

**A. cosmwasm-std >= 1.0 Overflow Behavior**
- Since cosmwasm-std 1.0, `Uint128` arithmetic ops (`+`, `-`, `*`) **PANIC on overflow** via `Add`/`Sub`/`Mul` trait impls
- This means `a + b` on Uint128 is already "checked" — it will abort the tx on overflow
- CVE-2024-58263 only affects versions < 1.0 where wrapping was the default
- **Implication:** For contracts using cosmwasm-std >= 1.0, our query fires on safe code
- **Fix:** Add context note in query metadata; optionally detect cosmwasm-std version from Cargo.toml

**B. Non-Financial "amount" Variables**
- `amount` in loop counters, array lengths, message counts
- `total` in pagination (`total_count`, `total_pages`)
- `balance` in non-financial contexts (load balancing, etc.)
- **Fix:** Require operand to be in a function that also does storage writes or returns Response

**C. Const/Static Expressions**
- `const MAX_SUPPLY: u128 = 1_000_000 * 10u128.pow(6);` — compile-time, can't overflow at runtime
- **Fix:** Exclude `BinaryArithmeticOperation` inside `ConstExpr` or static items

**D. Already-Checked Values**
- `let total = checked_add(a, b)?; let x = total + 1;` — second op flagged but value is bounded
- **Fix:** Hard to solve statically; document as known limitation

**E. Library Code (Not User-Written)**
- Operations inside `cosmwasm_std`, `cw_storage_plus` crate source
- **Fix:** Filter by file path — exclude files in `.cargo/` or dependency directories

### Recommended Precision Improvements
1. Add file path filter: exclude `.cargo/registry/`, `target/`, dependency dirs
2. Add scope filter: only flag arithmetic inside functions that interact with storage or return Response
3. Add metadata note about cosmwasm-std >= 1.0 panicking behavior
4. Consider reducing severity from "warning" to "recommendation" given panic semantics

## 2. Dispatch Detection False Positives

### Current Approach
`ExecuteDispatch` = any `match` expr inside `execute()`. Then checks each arm's called function for storage writes without auth.

### Known FP Sources

**A. Multiple Match Expressions**
- `execute()` may contain a preliminary match (e.g., on config state) before the msg dispatch
- Each match is treated as a dispatch → non-dispatch matches fire false positives
- **Fix:** Heuristic — require the match scrutinee to reference the last parameter (msg) of execute()

**B. Top-Level Auth Before Dispatch**
- Pattern: `if info.sender != admin { return Err(...) }; match msg { ... }`
- Auth is at execute level, not in handler functions
- Our query checks auth INSIDE the handler — misses execute-level guards
- **Fix:** Also check if the enclosing `execute()` function itself has auth checks

**C. Intentionally Public Handlers**
- Some execute msg variants are meant to be callable by anyone (e.g., `Claim`, `Withdraw`)
- These write storage but don't need auth — it's by design
- **Fix:** Allow annotation-based suppression; document as "review needed" not "vulnerability"

**D. Indirect Dispatch (Closures/Trait Objects)**
- `match msg { X => handlers[0](deps) }` — no static target resolvable
- `call.getStaticTarget()` returns nothing → silently skipped (false negative, not FP)

**E. Auth via SubMsg/Cross-Contract**
- Handler delegates auth to another contract via SubMsg
- No local auth check visible → flagged as missing auth
- **Fix:** If function dispatches SubMsg, reduce confidence; hard to fix fully

**F. cw-ownable / cw-controllers Patterns**
- Many contracts use `cw_ownable::assert_owner(deps.storage, &info.sender)?`
- This is a method call, not a direct comparison — may not match our auth patterns
- **Fix:** Add `assert_owner`, `is_admin`, `can_execute` to auth method name patterns

## 3. Precision Targets for Mature CodeQL Packs

| Precision | FP Rate | Use Case |
|-----------|---------|----------|
| `very-high` | <1% | Default SARIF display, CI blocking |
| `high` | <5% | Code scanning alerts |
| `medium` | <15% | Extended analysis, auditor review |
| `low` | <30% | Research, exhaustive scanning |

- GitHub Code Scanning shows `high`+ by default
- Recommended: Target `high` for access-control queries, `medium` for heuristic queries
- Arithmetic query should stay `medium` given heuristic nature

## 4. FP Reduction Techniques

1. **Scope narrowing:** Only flag findings in user-written contract code (not deps)
2. **Context enrichment:** Require multiple signals (storage write + no auth + entry point reachable)
3. **Suppression comments:** Support `// codeql[cosmwasm/query-id]` inline suppression
4. **Confidence tiers:** Tag findings with confidence (high/medium/low) for filtering
5. **Negative patterns:** Maintain exclusion list of safe patterns (checked math wrappers, known auth helpers)

## Unresolved Questions

1. Should we version-gate the arithmetic query (only flag if cosmwasm-std < 1.0)?
2. How to detect cosmwasm-std version from CodeQL database (Cargo.toml is extracted)?
3. Should dispatch detection require scrutinee to be the `msg` parameter specifically?
