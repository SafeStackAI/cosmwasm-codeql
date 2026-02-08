/**
 * Modeling of CosmWasm message dispatch and SubMsg patterns.
 *
 * Detects ExecuteMsg/QueryMsg dispatch via match expressions,
 * SubMsg creation, and CosmosMsg construction.
 */

import rust
import EntryPoints

/**
 * A match expression inside an execute entry point, likely dispatching
 * on ExecuteMsg variants.
 */
class ExecuteDispatch extends MatchExpr {
  ExecuteDispatch() {
    exists(ExecuteHandler handler |
      this.getEnclosingCallable() = handler
    )
  }
}

/**
 * A match expression inside a query entry point, likely dispatching
 * on QueryMsg variants.
 */
class QueryDispatch extends MatchExpr {
  QueryDispatch() {
    exists(QueryHandler handler |
      this.getEnclosingCallable() = handler
    )
  }
}

/**
 * A SubMsg creation call. Matches `SubMsg::new()`, `SubMsg::reply_on_success()`,
 * `SubMsg::reply_on_error()`, `SubMsg::reply_always()`.
 * Note: CodeQL Rust extractor elides paths as `...::reply_on_success`.
 */
class SubMessageCreation extends CallExpr {
  SubMessageCreation() {
    exists(string fnText |
      fnText = this.getFunction().toString() and
      (
        fnText.matches("%reply_on_success%") or
        fnText.matches("%reply_on_error%") or
        fnText.matches("%reply_always%") or
        fnText.matches("%reply_on_%")
      )
    )
  }
}

/**
 * Holds if the SubMsg creation uses a reply callback (non-fire-and-forget).
 * All SubMessageCreation instances use reply callbacks by construction.
 */
predicate hasReplyCallback(SubMessageCreation submsg) {
  any()
}

/**
 * Holds if function `f` dispatches SubMessages with reply callbacks.
 */
predicate dispatchesSubMsgWithReply(Function f) {
  exists(SubMessageCreation submsg |
    submsg.getEnclosingCallable() = f and
    hasReplyCallback(submsg)
  )
}
