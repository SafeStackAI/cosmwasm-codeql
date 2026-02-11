/**
 * CosmWasm smart contract modeling library for CodeQL.
 *
 * Provides comprehensive modeling of CosmWasm-specific patterns:
 * - Entry point detection (instantiate, execute, query, migrate, reply, IBC)
 * - Storage operations (Item, Map, IndexedMap read/write/delete)
 * - Message dispatch (ExecuteMsg, QueryMsg, SubMsg)
 * - Authorization checks (info.sender validation)
 */

import rust
import EntryPoints
import Storage
import Messages
import Authorization

/**
 * Holds if `f` is user-written contract code (not dependency, build artifact, or test).
 * Excludes:
 * - `.cargo/` (registry dependencies)
 * - `target/` (build output)
 * - Rust test files and directories
 */
predicate isUserContractCode(File f) {
  not f.getAbsolutePath().matches("%/.cargo/%") and
  not f.getAbsolutePath().matches("%/target/%") and
  // Test file basenames
  not f.getBaseName().matches("%_test.rs") and
  not f.getBaseName().matches("%_tests.rs") and
  not f.getBaseName() = "tests.rs" and
  not f.getBaseName().matches("test_%.rs") and
  // Test directories
  not f.getAbsolutePath().matches("%/contracts/test/%") and
  not f.getAbsolutePath().matches("%/contracts/testing/%") and
  not f.getAbsolutePath().matches("%/testing/%") and
  not f.getAbsolutePath().matches("%/tests/%") and
  not f.getAbsolutePath().matches("%/test_tube/%")
}

/**
 * Holds if `item` is inside a Rust test module (mod tests { ... }).
 * Catches `#[cfg(test)]` modules by conventional name.
 */
predicate isInTestModule(Locatable item) {
  exists(Module m |
    (m.getName().getText() = "tests" or m.getName().getText() = "test") and
    item.getLocation().getFile() = m.getLocation().getFile() and
    item.getLocation().getStartLine() >= m.getLocation().getStartLine() and
    item.getLocation().getEndLine() <= m.getLocation().getEndLine()
  )
}
