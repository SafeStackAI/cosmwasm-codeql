/**
 * @name Missing authorization in execute handler
 * @description Execute handler modifies contract state without verifying caller identity.
 *              An attacker could call this handler to make unauthorized state changes.
 * @kind problem
 * @id cosmwasm/missing-execute-authorization
 * @problem.severity error
 * @precision high
 * @tags security
 *       external/cwe/cwe-862
 */

import rust
import src.lib.CosmWasm

from Function handler, StorageWrite write
where
  // handler writes to storage
  write.getEnclosingCallable() = handler and
  // handler has a CosmWasm entry point signature or is called from execute dispatch
  (
    handler instanceof ExecuteHandler or
    exists(ExecuteHandler ep, Call call |
      call.getEnclosingCallable() = ep and
      call.getStaticTarget() = handler
    )
  ) and
  // handler lacks authorization check (including 1-level transitive callees)
  not hasAuthorizationCheckTransitive(handler) and
  // exclude self-serve handlers (sender operates on own data)
  not isSelfServeHandler(handler) and
  // exclude query-only handlers (no DepsMut)
  not handler instanceof QueryHandler and
  // exclude dependency, build artifact, and test code
  isUserContractCode(handler.getLocation().getFile()) and
  not isInTestModule(handler)
select handler,
  "Execute handler '" + handler.getName().getText() +
    "' modifies state without authorization check."
