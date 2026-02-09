# Real-World CosmWasm Projects for E2E Testing

**Date:** 2026-02-08
**Research Focus:** Identifying production-grade CosmWasm contracts suitable for end-to-end CodeQL testing

## Executive Summary

Identified 5 real-world CosmWasm project families with varying complexity levels, security audit histories, and architectural patterns. These projects provide authentic test targets covering access control, storage safety, and cross-contract communication patterns that CodeQL queries are designed to detect.

---

## 1. Osmosis Protocol Contracts

### Repository
- **Main:** [github.com/osmosis-labs/osmosis](https://github.com/osmosis-labs/osmosis)
- **Bindings:** [github.com/osmosis-labs/bindings](https://github.com/osmosis-labs/bindings)
- **Template:** [github.com/osmosis-labs/cw-tpl-osmosis](https://github.com/osmosis-labs/cw-tpl-osmosis)

### Characteristics
- **Focus:** AMM (Automated Market Maker) with concentrated liquidity pool contracts
- **Complexity:** High (financial contracts with precision-critical math)
- **Security Relevance:**
  - Storage management across liquidity positions
  - Cross-contract calls to pool modules
  - Authorization checks on fund transfers

### Key Patterns
- Custom bindings for Osmosis chain-specific operations
- Position tracking with storage optimization
- Precision handling for decimal scaling (12 decimal target)
- Fund transfer validation

### Audit History
- Actively maintained with focus on concentrated liquidity contracts
- Precision issues documented as design consideration

---

## 2. CosmWasm Reference Implementations (cw-plus)

### Repository
- **Main:** [github.com/CosmWasm/cw-plus](https://github.com/CosmWasm/cw-plus)

### Characteristics
- **Focus:** Production-quality standard contracts (CW20, CW721, etc.)
- **Complexity:** Medium (well-structured, audited reference implementations)
- **Security Relevance:**
  - Address normalization and case sensitivity vulnerabilities
  - Token transfer authorization patterns
  - Storage initialization and access patterns

### Known Vulnerabilities (Documented in Audits)
- **Address Case Sensitivity Issue:** Any CW20/CW721 transfer to capitalized addresses fails due to direct address comparison
- **Bypass Vectors:** Attackers can exploit address case sensitivity in deny-lists or access control
- **Fund Locking:** Staking contracts fail to validate beneficiary addresses, causing funds to lock if uppercase address provided

### Audit Resources
- [CosmWasm Security Spotlight Series](https://medium.com/oak-security/cosmwasm-security-spotlight-3-2b11f36fd61)
- [Oak Security CosmWasm Audits](https://github.com/oak-security/audit-reports/tree/master/CosmWasm)
- [JCSec CosmWasm Audit Roadmap](https://github.com/jcsec-security/Cosmwasm-Audit-roadmap)

---

## 3. Stargaze Launchpad Contracts

### Repository
- **Main:** [github.com/public-awesome/launchpad](https://github.com/public-awesome/launchpad)

### Characteristics
- **Focus:** NFT minting and collection management system
- **Complexity:** Medium-High (multi-contract governance system)
- **Contract Types:**
  - Minter factories (governance-parameterized)
  - Minters (pluggable types for custom minting logic)
  - SG-721 collection contracts (CW721 extension with metadata)

### Security Relevance
- Multi-contract coordination patterns
- Governance verification and blocking mechanisms
- Developer fee mechanisms and access control
- Collection-level metadata management
- CW721 compatibility and extension patterns

### Key Patterns
- Factory pattern for contract instantiation
- Governance integration for parameter management
- Developer incentive fee-sharing logic
- Standards compliance (100% CW721 compatible)

---

## 4. DAO DAO Governance Contracts

### Repository
- **Main:** [github.com/DA0-DA0/dao-contracts](https://github.com/DA0-DA0/dao-contracts)
- **Ecosystem:** Built into Juno Network infrastructure

### Characteristics
- **Focus:** Decentralized autonomous organization governance
- **Complexity:** High (sophisticated governance and voting logic)
- **Security Relevance:**
  - Authorization and permission delegation
  - Voting and quorum calculations
  - Treasury management
  - Proposal execution and conditional logic

### Key Patterns
- Role-based access control (RBAC)
- State transitions and voting workflows
- Cross-contract proposal execution
- Treasury fund management with authorization

### Ecosystem Context
- Juno Network official governance solution
- Tightly integrated into Juno's SubDAO structure
- Used for protocol-level governance decisions

---

## 5. JCSec CosmWasm Security Spotlight Projects

### Resources
- **Audit Roadmap:** [github.com/jcsec-security/Cosmwasm-Audit-roadmap](https://github.com/jcsec-security/Cosmwasm-Audit-roadmap)
- **Security Spotlight Labs:** [github.com/jcsec-security/cosmwasm-security-spotlight](https://github.com/jcsec-security/cosmwasm-security-spotlight)

### Characteristics
- **Focus:** Security vulnerability patterns and audit techniques
- **Complexity:** Low-Medium (educational contracts demonstrating vulnerabilities)
- **Security Relevance:**
  - Documented common pitfalls
  - Intentional vulnerability patterns for learning
  - Audit methodology reference

### Value for E2E Testing
- Provides authoritative vulnerability patterns for CodeQL validation
- Documents real audit findings from production contracts
- Establishes baseline security issues to detect

---

## Testing Suitability Matrix

| Project | Size | Complexity | Access Control | Storage Safety | Cross-Contract | Audit History |
|---------|------|-----------|-----------------|----------------|----------------|---------------|
| Osmosis | Large | High | ✓✓ | ✓✓ | ✓✓ | High |
| cw-plus | Medium | Medium | ✓✓ | ✓ | ✓ | Excellent |
| Stargaze | Large | Medium-High | ✓✓ | ✓ | ✓✓ | Good |
| DAO DAO | Large | High | ✓✓ | ✓✓ | ✓✓ | High |
| JCSec Labs | Small | Low-Medium | ✓ | ✓ | ✓ | N/A (Educational) |

---

## Recommended E2E Test Targets

### Tier 1 (Primary Targets)
1. **CosmWasm cw-plus:** Reference implementations with documented address validation vulnerabilities
2. **Stargaze Launchpad:** Multi-contract governance patterns with clear authorization boundaries

### Tier 2 (Advanced Targets)
3. **Osmosis Contracts:** Complex financial logic with storage optimization patterns
4. **DAO DAO:** Sophisticated governance with role-based access control

### Tier 3 (Validation Targets)
5. **JCSec Spotlight Labs:** Educational vulnerability patterns for query validation

---

## Key Vulnerability Patterns Identified

### Pattern 1: Address Case Sensitivity
- **Occurrence:** CW20, CW721 reference implementations
- **Impact:** Allows bypass of access control and fund locking
- **Detection:** CodeQL should identify `addr.to_string()` == comparison patterns

### Pattern 2: Storage Access Without Validation
- **Occurrence:** Staking contracts, pool contracts
- **Impact:** Fund misallocation or locking
- **Detection:** CodeQL should flag unchecked storage reads before use

### Pattern 3: Authorization Verification Gap
- **Occurrence:** Multi-contract systems, governance contracts
- **Impact:** Unauthorized operations or state changes
- **Detection:** CodeQL should identify missing `ensure!()` or assertion patterns

### Pattern 4: Cross-Contract Call Safety
- **Occurrence:** Multi-contract protocols
- **Impact:** Failed assumptions about called contract behavior
- **Detection:** CodeQL should validate result handling from `execute` calls

---

## Research Data Sources

- [Osmosis CosmWasm Integration Docs](https://docs.osmosis.zone/overview/integrate/on-chain/)
- [Osmosis Concentrated Liquidity Module](https://github.com/osmosis-labs/osmosis/tree/main/x/concentrated-liquidity)
- [CosmWasm cw-plus on GitHub](https://github.com/CosmWasm/cw-plus)
- [CosmWasm Security Spotlight #3](https://medium.com/oak-security/cosmwasm-security-spotlight-3-2b11f36fd61)
- [Oak Security Audit Reports](https://github.com/oak-security/audit-reports/tree/master/CosmWasm)
- [JCSec CosmWasm Audit Roadmap](https://github.com/jcsec-security/Cosmwasm-Audit-roadmap)
- [Stargaze Launchpad GitHub](https://github.com/public-awesome/launchpad)
- [Juno Network Documentation](https://junonetwork.io/)
- [DAO DAO Contracts](https://github.com/DA0-DA0/dao-contracts)
- [CosmosContracts GitHub Organization](https://github.com/CosmosContracts)

---

## Unresolved Questions

1. **Repository Cloning Strategy:** Should E2E tests clone full repo or use minimal contract subsets? (Size vs. authenticity tradeoff)
2. **Version Pinning:** Should tests target specific commit hashes or branches? (Stability vs. currency)
3. **Dependency Resolution:** How to handle local vs. remote dependency resolution during CodeQL pack analysis?
4. **Query Tolerance:** What false positive/negative rates are acceptable for E2E validation?
5. **Performance Baseline:** What are acceptable CodeQL query execution times for real-world contract suites?

