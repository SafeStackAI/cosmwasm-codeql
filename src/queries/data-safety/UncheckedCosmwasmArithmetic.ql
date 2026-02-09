/**
 * @name Unchecked arithmetic on CosmWasm integer types
 * @description Arithmetic operations on Uint128/Uint256 without overflow checks.
 *              cosmwasm-std < 1.0 uses wrapping math by default (CVE-2024-58263).
 *              Note: cosmwasm-std >= 1.0 Uint128/Uint256 ops panic on overflow,
 *              which is safe for most use cases. This query targets contracts
 *              that may use older versions or custom integer types.
 * @kind problem
 * @id cosmwasm/unchecked-cosmwasm-arithmetic
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       external/cwe/cwe-190
 */

import rust
import src.lib.CosmWasm

from BinaryArithmeticOperation arith, Function f
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
  // Exclude dependency, build artifact, and test code
  isUserContractCode(arith.getLocation().getFile()) and
  // Must be inside a real function (not const/static initializer) that interacts
  // with storage or returns Response — limits to financial-risk surface
  arith.getEnclosingCallable() = f and
  f.getNumberOfParams() > 0 and
  (
    hasStorageWrite(f) or
    hasStorageRead(f) or
    f.getRetType().toString().matches("%Response%") or
    f.getRetType().toString().matches("%Result%")
  )
select arith,
  "Unchecked arithmetic on potential CosmWasm integer type. Use checked_add/checked_sub/checked_mul instead."
