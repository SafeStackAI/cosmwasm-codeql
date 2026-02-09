/**
 * @name Reply handler ignoring errors
 * @description Reply handler does not inspect Reply.result field.
 *              Error cases from SubMsg execution may be silently ignored,
 *              leading to inconsistent contract state.
 * @kind problem
 * @id cosmwasm/reply-handler-ignoring-errors
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       external/cwe/cwe-390
 */

import rust
import src.lib.CosmWasm

from ReplyHandler reply
where
  // Reply handler does not access the "result" field of the Reply struct
  not exists(FieldExpr f |
    f.getEnclosingCallable() = reply and
    f.getIdentifier().toString() = "result"
  ) and
  // Also check for match on the reply msg parameter
  not exists(MatchExpr m |
    m.getEnclosingCallable() = reply
  ) and
  isUserContractCode(reply.getLocation().getFile())
select reply,
  "Reply handler does not inspect Reply.result. Error cases from SubMsg execution may be silently ignored."
