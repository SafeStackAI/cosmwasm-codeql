/**
 * @name Storage key collision
 * @description Multiple storage declarations use the same string key prefix,
 *              causing state corruption when reading/writing.
 * @kind problem
 * @id cosmwasm/storage-key-collision
 * @problem.severity error
 * @precision high
 * @tags security
 *       correctness
 */

import rust
import src.lib.CosmWasm

/**
 * Gets the string literal argument from a storage declaration call.
 * Matches patterns like `Item::new("key")` or `Map::new("key")`.
 */
string getStorageKey(StorageDeclaration decl) {
  exists(LiteralExpr lit |
    lit = decl.getArgList().getArg(0) and
    result = lit.toString()
  )
}

from StorageDeclaration decl1, StorageDeclaration decl2, string key
where
  key = getStorageKey(decl1) and
  key = getStorageKey(decl2) and
  // Different declarations with same key
  decl1 != decl2 and
  // In the same file (same contract)
  decl1.getLocation().getFile() = decl2.getLocation().getFile() and
  // Avoid duplicate reports (only report once per pair)
  decl1.getLocation().getStartLine() < decl2.getLocation().getStartLine() and
  isUserContractCode(decl1.getLocation().getFile())
select decl1,
  "Storage key " + key + " is also used by another declaration at line " +
    decl2.getLocation().getStartLine().toString() + ". This causes state corruption."
