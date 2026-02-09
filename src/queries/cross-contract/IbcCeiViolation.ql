/**
 * @name IBC handler CEI pattern violation
 * @description IBC handler performs state changes and dispatches messages.
 *              This may violate the checks-effects-interactions pattern,
 *              enabling reentrancy via IBC timeout callbacks (ASA-2024-007).
 * @kind problem
 * @id cosmwasm/ibc-cei-violation
 * @problem.severity error
 * @precision medium
 * @tags security
 *       external/cwe/cwe-841
 */

import rust
import src.lib.CosmWasm

from IbcEntryPoint ibc, StorageAccess stateChange
where
  stateChange.getEnclosingCallable() = ibc and
  // State modification: write, update, or delete
  stateChange.getMethodName() in ["save", "update", "remove"] and
  // IBC handler also constructs response messages (add_message, add_submessage)
  exists(MethodCallExpr msgCall |
    msgCall.getEnclosingCallable() = ibc and
    msgCall.getIdentifier().toString() in [
        "add_message", "add_messages", "add_submessage", "add_submessages"
      ]
  ) and
  isUserContractCode(ibc.getLocation().getFile())
select ibc,
  "IBC handler '" + ibc.getName().getText() +
    "' performs state changes and dispatches messages. Verify CEI pattern compliance to prevent reentrancy."
