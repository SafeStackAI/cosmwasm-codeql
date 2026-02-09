/**
 * Modeling of CosmWasm authorization patterns.
 *
 * Detects `info.sender` access and authorization checks
 * (comparisons of sender against stored admin/owner values).
 */

import rust

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
 * - Sender access followed by Unauthorized error path
 * - Call to a helper function with auth-related name
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
      call.getIdentifier().toString().matches("%validate_sender%")
    )
  )
  or
  // Sender access + Unauthorized error return pattern
  exists(SenderAccess sa |
    sa.getEnclosingCallable() = f
  ) and
  exists(PathExpr err |
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
        name.matches("%assert_admin%")
      )
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
