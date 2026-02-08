/**
 * @name Unchecked unwrap on storage operation
 * @description Calling .unwrap() on storage read can panic if key does not exist.
 *              Use the ? operator or explicit error handling instead.
 * @kind problem
 * @id cosmwasm/unchecked-storage-unwrap
 * @problem.severity warning
 * @precision high
 * @tags security
 *       external/cwe/cwe-252
 */

import rust
import src.lib.CosmWasm

from MethodCallExpr unwrapCall, StorageRead storageRead
where
  unwrapCall.getIdentifier().toString() = "unwrap" and
  unwrapCall.getReceiver() = storageRead and
  not unwrapCall.getLocation().getFile().getBaseName().matches("%test%.rs")
select unwrapCall,
  "Unchecked .unwrap() on storage read '" + storageRead.getMethodName() +
    "()'. Handle the error case explicitly with '?' operator."
