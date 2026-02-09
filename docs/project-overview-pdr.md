# CosmWasm CodeQL — Project Overview & PDR

**Version:** 1.0
**Last Updated:** February 2026
**Pack ID:** lucasamorimca/cosmwasm-codeql (Apache-2.0)

---

## Executive Summary

CosmWasm CodeQL is an automated security analysis query pack for detecting common vulnerability patterns in Rust-based CosmWasm smart contracts. It provides 10 production-ready queries covering access control, data safety, and cross-contract communication risks.

The pack integrates with CodeQL's Rust static analysis engine, enabling security scans within GitHub Actions, local development workflows, and CI/CD pipelines. E2E validation against real-world contracts (cw-plus ecosystem) ensures practical precision.

---

## Project Goals & Scope

### Primary Goals
1. **Automated vulnerability detection** in CosmWasm contracts without requiring compilation
2. **High-precision queries** that minimize false positives while catching real security issues
3. **Developer-friendly integration** via CodeQL CLI, GitHub Actions, and per-query help documentation
4. **Ecosystem-validated** through testing against cw-plus v2.0.0 and broader CosmWasm ecosystem

### In Scope
- Static analysis of Rust source code using CodeQL's Rust AST
- Detection of 10 specific vulnerability categories (see query list below)
- Support for cosmwasm-std and cw-storage-plus libraries
- Local and CI/CD analysis workflows
- Test fixtures (vulnerable and safe contract examples)
- Query-level precision tuning and false positive reduction

### Out of Scope
- Runtime analysis or simulation of contract execution
- Non-Rust smart contract languages
- Dynamic property-based testing
- Integration with contract deployment tools
- Formal verification of contract logic

---

## Functional Requirements

### FR-1: Query Execution
**Requirement:** All 10 queries must execute against a CodeQL database without errors.
**Acceptance Criteria:**
- Each query produces valid SARIF output with findings or empty results
- Queries support local and remote (GitHub) databases
- Execution time < 30 seconds per query on typical contracts

### FR-2: Vulnerability Detection
**Requirement:** Queries must identify intended vulnerability patterns with reasonable precision.
**Acceptance Criteria:**
- Synthetic test suite: 20 unit tests, 100% pass rate
- E2E validation: Baseline findings documented; precision improvements tracked
- No regressions in synthetic tests after code changes

### FR-3: Authorization Pattern Recognition
**Requirement:** Detect diverse authorization mechanisms beyond simple `info.sender` comparisons.
**Acceptance Criteria:**
- Recognize assert/ensure/check macros
- Support external auth helpers (is_admin, can_execute, assert_owner, etc.)
- Detect execute-level and handler-level authorization checks
- Handle cw-ownable and cw-controllers patterns

### FR-4: False Positive Reduction
**Requirement:** Minimize false positives through scope and context filtering.
**Acceptance Criteria:**
- Exclude dependency code (.cargo/, target/)
- Filter out const/static expressions (compile-time safe)
- Context-aware scope narrowing (storage/response contexts for arithmetic)
- Per-query precision metrics updated based on E2E results

### FR-5: Documentation & Usability
**Requirement:** Each query has clear, actionable documentation.
**Acceptance Criteria:**
- Per-query help file (docs/query-help/*.md) with description, recommendation, examples
- README with quick start, query table, integration examples
- Code-standards documentation for library predicates
- GitHub Actions workflow example

---

## Non-Functional Requirements

### NFR-1: Performance
- Query execution: < 30 seconds per query on databases with 100K+ AST nodes
- Database creation: < 5 minutes for typical contracts (no compilation)

### NFR-2: Reliability
- Zero crashes on valid Rust source code
- Graceful handling of edge cases (empty files, malformed syntax in test code)
- 100% synthetic test pass rate after each code change

### NFR-3: Maintainability
- DRY principle: Shared predicates in library modules (CosmWasm.qll, Authorization.qll, etc.)
- Code is self-documenting via clear naming and comments
- Changes do not break existing queries (backward compatibility)

### NFR-4: Usability
- Single command to run all queries: `codeql database analyze`
- GitHub Actions integration with one copy-paste workflow
- Clear error messages on misconfiguration

---

## Technical Architecture

### Package Structure
```
lucasamorimca/cosmwasm-codeql/
├── src/
│   ├── queries/              # 10 CodeQL query files (.ql)
│   │   ├── access-control/   # 3 authorization-focused queries
│   │   ├── data-safety/      # 4 data integrity & safety queries
│   │   └── cross-contract/   # 3 external interaction queries
│   └── lib/                  # Shared library modules (.qll)
│       ├── CosmWasm.qll      # Entry points, general utilities
│       ├── EntryPoints.qll   # Handler detection (execute, migrate, etc.)
│       ├── Storage.qll       # Storage operation modeling
│       ├── Messages.qll      # Message dispatch detection
│       └── Authorization.qll # Sender access & auth pattern detection
├── test/
│   ├── fixtures/             # Test contract fixtures
│   │   ├── vulnerable-contract/
│   │   └── safe-contract/
│   ├── run-tests.sh          # Synthetic test harness
│   ├── e2e/                  # E2E testing infrastructure
│   │   ├── run-e2e.sh        # E2E orchestrator
│   │   └── parse-sarif.sh    # SARIF output parser
│   └── db/                   # Generated test databases
└── docs/
    ├── query-help/           # Per-query documentation
    ├── project-overview-pdr.md
    └── code-standards.md
```

### Core Design Patterns

**1. Entry Point Detection**
- Functions named execute, migrate, instantiate, reply, ibc_* with matching parameter counts
- Modeled in EntryPoints.qll via signature-based detection (no @entry_point attribute visible)

**2. Authorization Modeling**
- `SenderAccess` class: Field access for info.sender
- `hasAuthorizationCheck()` predicate: Multi-method detection (comparisons, macros, helper calls)
- Expanded helper patterns: is_admin, can_execute, can_modify, check_permission, validate_sender, assert_admin

**3. Shared Code Filtering**
- `isUserContractCode()` predicate: Excludes .cargo/, target/, test files
- Applied universally across all 10 queries (DRY consolidation)

**4. Scope-Aware Detection**
- Storage operations: save/load/may_load/update/remove
- Message dispatch: Match expressions on ExecuteMsg/QueryMsg
- Arithmetic: Filtered to storage/response contexts only

---

## Query Catalog

| Category | Query ID | Name | Severity | CWE |
|----------|----------|------|----------|-----|
| Access Control | cosmwasm/missing-execute-authorization | Missing authorization in execute handler | error | [CWE-862](https://cwe.mitre.org/data/definitions/862.html) |
| Access Control | cosmwasm/missing-migrate-authorization | Missing authorization in migrate handler | error | [CWE-862](https://cwe.mitre.org/data/definitions/862.html) |
| Access Control | cosmwasm/unprotected-execute-dispatch | Unprotected execute message dispatch | warning | [CWE-285](https://cwe.mitre.org/data/definitions/285.html) |
| Data Safety | cosmwasm/unchecked-cosmwasm-arithmetic | Unchecked arithmetic on CosmWasm integers | warning | [CWE-190](https://cwe.mitre.org/data/definitions/190.html) |
| Data Safety | cosmwasm/unchecked-storage-unwrap | Unchecked unwrap on storage operation | warning | [CWE-252](https://cwe.mitre.org/data/definitions/252.html) |
| Data Safety | cosmwasm/missing-address-validation | Missing address validation | warning | [CWE-20](https://cwe.mitre.org/data/definitions/20.html) |
| Data Safety | cosmwasm/storage-key-collision | Storage key collision | error | N/A |
| Cross-Contract | cosmwasm/ibc-cei-violation | IBC handler CEI pattern violation | error | [CWE-841](https://cwe.mitre.org/data/definitions/841.html) |
| Cross-Contract | cosmwasm/submsg-without-reply-handler | SubMsg with reply but no reply handler | warning | N/A |
| Cross-Contract | cosmwasm/reply-handler-ignoring-errors | Reply handler ignoring errors | warning | [CWE-390](https://cwe.mitre.org/data/definitions/390.html) |

---

## Validation & Precision Metrics

### Synthetic Testing (Unit Tests)
- **Test Suite:** 20 unit tests in vulnerable-contract and safe-contract fixtures
- **Pass Rate:** 100% (no regressions)
- **Database:** Single per-fixture database for comprehensive coverage

### E2E Testing (Real-World Contracts)
- **Targets:** cw-plus v2.0.0 (cw20-base, cw721-base, cw20-staking, cw4-group)
- **Baseline (Feb 2026):** 65 findings across 4 contracts
- **Final:** 36 findings (-45% reduction via precision tuning)
- **Precision Improvements:**
  - Arithmetic: 94% → ~6% false positive rate (dependency & scope filtering)
  - Dispatch: 92% → ~25% FP rate (msg-scrutinee validation, auth pattern expansion)
  - Overall: ~95% FP rate → ~45% FP rate

---

## Dependencies & Compatibility

### Required Tools
- CodeQL CLI >= 2.23.3
- Rust source code (no compilation required)

### Supported Libraries
- cosmwasm-std (all versions with support for Uint128, Uint256, Uint64)
- cw-storage-plus (Item, Map, IndexedMap)
- cw-ownable (assert_owner patterns)
- cw-controllers (is_admin, can_execute patterns)

### Target Contracts
- Any CosmWasm contract written in Rust
- Tested against cw-plus v2.0.0 ecosystem

---

## Known Limitations & Future Work

### Current Limitations
1. **Arithmetic Query:** Heuristic-based; relies on operand name patterns (amount, balance, supply)
2. **Auth Patterns:** Name-based matching does not validate semantic correctness
3. **Dispatch Detection:** Uses string matching on msg parameter names (may miss renamed parameters)
4. **FP Rate:** Final ~45% still above ideal <20% target; attributed to intentional design (public handlers, external auth helpers not fully recognized)

### Future Enhancement Candidates
1. **Version-gated arithmetic:** Detect cosmwasm-std version from Cargo.toml and adjust sensitivity
2. **Inline suppressions:** Support `// codeql[query-id]` comments for explicit exclusions
3. **Confidence tiers:** Classify findings as high/medium/low confidence
4. **Semantic auth validation:** Beyond pattern matching, validate auth logic structure
5. **Permanent E2E targets:** Stargaze, DAO DAO, additional ecosystem contracts
6. **Custom error suppression:** Per-finding annotations in query configuration

---

## Deployment & Maintenance

### Release Process
- Semantic versioning: major.minor.patch
- GitHub releases with CHANGELOG
- Registry deployment via CodeQL CLI registry

### Monitoring & Updates
- Track precision metrics against ecosystem contracts quarterly
- Update auth patterns based on emerging cw-* libraries
- Issue security advisories if new vulnerability patterns discovered

---

## References

- [CodeQL Documentation](https://codeql.github.com/)
- [Rust AST Reference](https://codeql.github.com/docs/codeql-language-guides/codeql-for-rust/)
- [CosmWasm Documentation](https://docs.cosmwasm.com/)
- [OWASP Smart Contract Top 10](https://owasp.org/www-project-smart-contract-top-10/)
