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
 * - Rust test modules (tests.rs, _test.rs, _tests.rs patterns)
 */
predicate isUserContractCode(File f) {
  not f.getAbsolutePath().matches("%/.cargo/%") and
  not f.getAbsolutePath().matches("%/target/%") and
  not f.getBaseName().matches("%_test.rs") and
  not f.getBaseName().matches("%_tests.rs") and
  not f.getBaseName() = "tests.rs"
}
