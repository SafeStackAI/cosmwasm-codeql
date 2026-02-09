/**
 * @name SubMsg with reply but no reply handler
 * @description Contract creates SubMsg with reply callback but has no reply()
 *              entry point. The reply will be silently dropped.
 * @kind problem
 * @id cosmwasm/submsg-without-reply-handler
 * @problem.severity warning
 * @precision high
 * @tags security
 *       correctness
 */

import rust
import src.lib.CosmWasm

from SubMessageCreation submsg
where
  hasReplyCallback(submsg) and
  // No reply entry point exists in the codebase
  not exists(ReplyHandler reply) and
  isUserContractCode(submsg.getLocation().getFile())
select submsg,
  "SubMsg created with reply callback but contract has no reply() entry point. Reply will be silently dropped."
