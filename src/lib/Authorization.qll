/**
 * Modeling of CosmWasm authorization patterns.
 *
 * Detects `info.sender` access and authorization checks
 * (comparisons of sender against stored admin/owner values).
 */

import rust
import Storage

/**
 * A field access expression accessing `info.sender`.
 * This is the primary caller identity in CosmWasm.
 */
class SenderAccess extends FieldExpr {
  SenderAccess() {
    this.getIdentifier().toString() = "sender" and
    this.getContainer().toString().matches("%info%")
  }
}

/**
 * Holds if function `f` contains an `info.sender` access.
 */
predicate accessesSender(Function f) {
  exists(SenderAccess sa |
    sa.getEnclosingCallable() = f
  )
}

/**
 * Holds if function `f` contains an authorization check.
 *
 * An authorization check is any of:
 * - Equality/inequality comparison involving `info.sender`
 * - Call to assert/ensure/check macros with sender
 * - Sender access followed by Unauthorized error path (struct literal or path expr)
 * - Call to a helper function with auth-related name
 * - Sender used as storage read key + Unauthorized error (membership auth)
 * - Status field gate check (state-machine auth)
 */
predicate hasAuthorizationCheck(Function f) {
  // Direct sender comparison: info.sender == x or info.sender != x
  exists(BinaryExpr cmp |
    cmp.getEnclosingCallable() = f and
    cmp.getOperatorName() in ["==", "!="] and
    (
      cmp.getLhs() instanceof SenderAccess or
      cmp.getRhs() instanceof SenderAccess
    )
  )
  or
  // Sender used in a method call (assert_eq, ensure_eq, etc.)
  // Also covers cw-ownable (assert_owner), cw-controllers (is_admin, can_execute)
  exists(MethodCallExpr call |
    call.getEnclosingCallable() = f and
    (
      call.getIdentifier().toString().matches("%assert%") or
      call.getIdentifier().toString().matches("%ensure%") or
      call.getIdentifier().toString().matches("%require%") or
      call.getIdentifier().toString().matches("%check%auth%") or
      call.getIdentifier().toString().matches("%verify%owner%") or
      call.getIdentifier().toString().matches("%only%owner%") or
      call.getIdentifier().toString().matches("%is_admin%") or
      call.getIdentifier().toString().matches("%can_execute%") or
      call.getIdentifier().toString().matches("%can_modify%") or
      call.getIdentifier().toString().matches("%check_permission%") or
      call.getIdentifier().toString().matches("%validate_sender%") or
      call.getIdentifier().toString().matches("%deduct_allowance%")
    )
  )
  or
  // Sender access + Unauthorized error return pattern.
  // Uses Expr (not PathExpr) to catch struct literals like ContractError::Unauthorized {}
  exists(SenderAccess sa |
    sa.getEnclosingCallable() = f
  ) and
  exists(Expr err |
    err.getEnclosingCallable() = f and
    err.toString().matches("%Unauthorized%")
  )
  or
  // Call to auth helper function (free functions and qualified calls)
  exists(CallExpr call |
    call.getEnclosingCallable() = f and
    exists(string name |
      name = call.getFunction().toString() and
      (
        name.matches("%check_auth%") or
        name.matches("%verify_sender%") or
        name.matches("%assert_owner%") or
        name.matches("%ensure_admin%") or
        name.matches("%only_admin%") or
        name.matches("%only_owner%") or
        name.matches("%require_admin%") or
        name.matches("%is_admin%") or
        name.matches("%can_execute%") or
        name.matches("%can_modify%") or
        name.matches("%check_permission%") or
        name.matches("%validate_sender%") or
        name.matches("%assert_admin%") or
        name.matches("%deduct_allowance%")
      )
    )
  )
  or
  // Sender-as-storage-key implicit auth: info.sender in storage read key + error check
  hasSenderStorageKeyAuth(f)
  or
  // Status field gate check (proposal.status == Passed etc.)
  hasStatusGateCheck(f)
  or
  // Parameter-passing auth: dispatch passes info.sender as "sender" param,
  // handler compares it against something + returns Unauthorized
  hasParamBasedAuth(f)
  or
  // Voting power / membership gate: function checks caller's voting power or permission
  hasVotingPowerAuth(f)
}

/**
 * Holds if `sender` is structurally within `arg` (location containment).
 * Needed because toString() on RefExpr(&info.sender) truncates to "&...".
 */
private predicate senderInArg(SenderAccess sender, Expr arg) {
  sender.getLocation().getFile() = arg.getLocation().getFile() and
  sender.getLocation().getStartLine() >= arg.getLocation().getStartLine() and
  sender.getLocation().getEndLine() <= arg.getLocation().getEndLine() and
  (
    sender.getLocation().getStartLine() > arg.getLocation().getStartLine()
    or
    sender.getLocation().getStartColumn() >= arg.getLocation().getStartColumn()
  ) and
  (
    sender.getLocation().getEndLine() < arg.getLocation().getEndLine()
    or
    sender.getLocation().getEndColumn() <= arg.getLocation().getEndColumn()
  )
}

/**
 * Holds if `f` contains sender-as-storage-key implicit authorization.
 * Pattern: info.sender flows into Map key param of a storage read + error-checked result.
 * Example: VOTERS.may_load(deps.storage, &info.sender)?.ok_or(Unauthorized{})?
 */
predicate hasSenderStorageKeyAuth(Function f) {
  // Sender used as argument in a storage read call within this function
  exists(StorageRead read, SenderAccess sender, Expr arg |
    read.getEnclosingCallable() = f and
    sender.getEnclosingCallable() = f and
    arg = read.getArgList().getAnArg() and
    senderInArg(sender, arg)
  )
  and
  // Error path contains Unauthorized (any expression form)
  exists(Expr err |
    err.getEnclosingCallable() = f and
    err.toString().matches("%Unauthorized%")
  )
}

/**
 * Holds if `f` contains a status-based gate check (state-machine auth).
 * Pattern: load record -> check .status field -> error on mismatch.
 * Example: if prop.status != Status::Passed { return Err(...) }
 */
predicate hasStatusGateCheck(Function f) {
  // Field access to .status within the function
  exists(FieldExpr statusAccess |
    statusAccess.getEnclosingCallable() = f and
    statusAccess.getIdentifier().toString() = "status"
  )
  and
  (
    // Comparison: x.status == SomeVariant or x.status != SomeVariant
    exists(BinaryExpr cmp |
      cmp.getEnclosingCallable() = f and
      cmp.getOperatorName() in ["==", "!="] and
      (
        cmp.getLhs().toString().matches("%status%") or
        cmp.getRhs().toString().matches("%status%")
      )
    )
    or
    // Match on status: match prop.status { Status::Passed => ..., _ => Err(...) }
    exists(MatchExpr m |
      m.getEnclosingCallable() = f and
      m.getScrutinee().toString().matches("%status%")
    )
  )
}

/**
 * Holds if `f` is a self-serve handler where sender operates on own data.
 * Pattern: info.sender used as key in storage write (save/update).
 * Self-serve handlers need no auth — sender can only affect own records.
 * Excludes functions that also load admin/owner/config (privileged ops).
 */
predicate isSelfServeHandler(Function f) {
  (
    // Direct: info.sender used as key in a storage write
    exists(StorageWrite write, SenderAccess sender, Expr arg |
      write.getEnclosingCallable() = f and
      sender.getEnclosingCallable() = f and
      arg = write.getArgList().getAnArg() and
      senderInArg(sender, arg)
    )
    or
    // Indirect: function has a "sender" param and uses it in a storage write arg
    exists(StorageWrite write, Param p |
      write.getEnclosingCallable() = f and
      p = f.getAParam() and
      p.getPat().toString() = "sender" and
      write.getArgList().getAnArg().toString().matches("%sender%")
    )
  )
  and
  // NOT a privileged handler (no admin/owner storage reads — CONFIG excluded
  // because many contracts load config for non-auth purposes like reading params)
  not exists(StorageRead adminLoad |
    adminLoad.getEnclosingCallable() = f and
    (
      adminLoad.getReceiver().toString().matches("%ADMIN%") or
      adminLoad.getReceiver().toString().matches("%OWNER%")
    )
  )
}

/**
 * Holds if `f` has auth check directly OR in a direct callee (1-level deep).
 * Covers the common pattern: execute_handler -> check_auth_helper.
 */
predicate hasAuthorizationCheckTransitive(Function f) {
  hasAuthorizationCheck(f)
  or
  exists(Call call, Function callee |
    call.getEnclosingCallable() = f and
    callee = call.getStaticTarget() and
    hasAuthorizationCheck(callee)
  )
}

/**
 * Holds if `f` has parameter-based authorization.
 * Pattern: dispatch extracts info.sender and passes as "sender" Addr param;
 * handler compares it or uses it in an auth-returning path.
 * Example: execute_pause(deps, env, sender: Addr, ...) { if sender != X { Unauthorized } }
 */
predicate hasParamBasedAuth(Function f) {
  exists(Param p |
    p = f.getAParam() and
    p.getPat().toString() = "sender"
  ) and
  exists(Expr err |
    err.getEnclosingCallable() = f and
    err.toString().matches("%Unauthorized%")
  )
}

/**
 * Holds if `f` gates on voting power or membership permission.
 * Pattern: call to get_voting_power/is_permitted + zero/denial check.
 * Example: let power = get_voting_power(sender)?; if power.is_zero() { ... }
 */
predicate hasVotingPowerAuth(Function f) {
  // Free function call to voting power lookup
  exists(CallExpr call |
    call.getEnclosingCallable() = f and
    call.getFunction().toString().matches("%voting_power%")
  )
  or
  // Method call to permission check (is_permitted, has_voting_power)
  exists(MethodCallExpr call |
    call.getEnclosingCallable() = f and
    (
      call.getIdentifier().toString().matches("%is_permitted%") or
      call.getIdentifier().toString().matches("%voting_power%")
    )
  )
}

/**
 * Holds if function `f` accesses sender but lacks an authorization check.
 */
predicate missingAuthorizationWithSenderAccess(Function f) {
  accessesSender(f) and
  not hasAuthorizationCheck(f)
}
