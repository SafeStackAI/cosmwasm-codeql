/**
 * @name Unchecked arithmetic on CosmWasm integer types
 * @description Arithmetic operations on Uint128/Uint256 without overflow checks.
 *              cosmwasm-std uses wrapping math by default (CVE-2024-58263).
 *              Use checked_add/checked_sub/checked_mul instead.
 * @kind problem
 * @id cosmwasm/unchecked-cosmwasm-arithmetic
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       external/cwe/cwe-190
 */

import rust

from BinaryArithmeticOperation arith
where
  arith.getOperatorName() in ["+", "-", "*"] and
  // Heuristic: at least one operand references a cosmwasm numeric field or variable
  (
    arith.getLhs().toString().regexpMatch(".*(amount|balance|total|supply|price|quantity|reward|stake|fee|deposit|withdraw).*") or
    arith.getRhs().toString().regexpMatch(".*(amount|balance|total|supply|price|quantity|reward|stake|fee|deposit|withdraw).*") or
    arith.getLhs().toString().regexpMatch(".*[Uu]int(128|256).*") or
    arith.getRhs().toString().regexpMatch(".*[Uu]int(128|256).*")
  ) and
  // Exclude checked math patterns (checked_add result)
  not arith.toString().matches("%checked_%") and
  // Exclude Rust test modules
  not arith.getLocation().getFile().getBaseName().matches("%test%.rs")
select arith,
  "Unchecked arithmetic on potential CosmWasm integer type. Use checked_add/checked_sub/checked_mul instead."
