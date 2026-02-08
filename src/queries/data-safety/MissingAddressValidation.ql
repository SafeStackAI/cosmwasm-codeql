/**
 * @name Missing address validation
 * @description User-provided address stored or used in messages without
 *              deps.api.addr_validate() call. Invalid addresses can cause
 *              fund loss or bypass access controls.
 * @kind problem
 * @id cosmwasm/missing-address-validation
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       external/cwe/cwe-20
 */

import rust
import src.lib.CosmWasm

/**
 * Holds if function `f` calls `addr_validate`.
 */
predicate callsAddrValidate(Function f) {
  exists(MethodCallExpr call |
    call.getEnclosingCallable() = f and
    call.getIdentifier().toString() = "addr_validate"
  )
}

from Function handler, CallExpr uncheckedCall
where
  // Function is a CosmWasm entry point or called from one
  (
    handler instanceof CosmWasmEntryPoint or
    exists(CosmWasmEntryPoint ep, Call call |
      call.getEnclosingCallable() = ep and
      call.getStaticTarget() = handler
    )
  ) and
  // Uses Addr::unchecked (extractor elides path as ...::unchecked)
  uncheckedCall.getEnclosingCallable() = handler and
  uncheckedCall.getFunction().toString().matches("%unchecked%") and
  not uncheckedCall.getFunction().toString().matches("%unchecked_into%") and
  // Does not also call addr_validate in the same function
  not callsAddrValidate(handler) and
  not handler.getLocation().getFile().getBaseName().matches("%test%.rs")
select uncheckedCall,
  "Address created with Addr::unchecked() in '" + handler.getName().getText() +
    "' without addr_validate(). Use deps.api.addr_validate() for user-provided addresses."
