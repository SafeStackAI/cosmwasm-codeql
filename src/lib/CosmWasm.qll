/**
 * CosmWasm smart contract modeling library for CodeQL.
 *
 * Provides comprehensive modeling of CosmWasm-specific patterns:
 * - Entry point detection (instantiate, execute, query, migrate, reply, IBC)
 * - Storage operations (Item, Map, IndexedMap read/write/delete)
 * - Message dispatch (ExecuteMsg, QueryMsg, SubMsg)
 * - Authorization checks (info.sender validation)
 */

import EntryPoints
import Storage
import Messages
import Authorization
