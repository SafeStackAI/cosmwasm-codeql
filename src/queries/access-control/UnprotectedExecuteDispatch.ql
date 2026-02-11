/**
 * @name Unprotected execute message dispatch
 * @description Execute message variant dispatches to handler that modifies state
 *              without authorization check.
 * @kind problem
 * @id cosmwasm/unprotected-execute-dispatch
 * @problem.severity warning
 * @precision medium
 * @tags security
 *       external/cwe/cwe-285
 */

import rust
import src.lib.CosmWasm

from ExecuteDispatch dispatch, MatchArm arm, Call call, Function target
where
  arm = dispatch.getMatchArmList().getAnArm() and
  // Call may be direct or inside a block expression
  call.getEnclosingCallable() = dispatch.getEnclosingCallable() and
  call.getLocation().getFile() = arm.getLocation().getFile() and
  call.getLocation().getStartLine() >= arm.getLocation().getStartLine() and
  call.getLocation().getStartLine() <= arm.getLocation().getEndLine() and
  target = call.getStaticTarget() and
  hasStorageWrite(target) and
  // Check auth in both the handler AND the enclosing execute function (1-level transitive)
  not hasAuthorizationCheckTransitive(target) and
  not hasAuthorizationCheck(dispatch.getEnclosingCallable()) and
  // Exclude self-serve handlers (sender operates on own data)
  not isSelfServeHandler(target) and
  // Exclude dependency, build artifact, and test code
  isUserContractCode(target.getLocation().getFile()) and
  not isInTestModule(target)
select arm,
  "Dispatch arm calls '" + target.getName().getText() +
    "' which modifies state without authorization."
