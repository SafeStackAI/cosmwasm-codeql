/**
 * Modeling of CosmWasm smart contract entry points.
 *
 * Provides classes to identify CosmWasm entry point functions using
 * dual detection: attribute-based (#[entry_point]) and signature-based
 * (function name + parameter count fallback).
 */

import rust

/**
 * Holds if attribute `a` is a CosmWasm `#[entry_point]` annotation.
 * Matches both `#[entry_point]` and `#[cosmwasm_std::entry_point]`.
 */
predicate isEntryPointAttr(Attr a) {
  exists(string path |
    path = a.getMeta().getPath().toString() and
    (path.matches("%entry_point%"))
  )
}

/**
 * Holds if function `f` has the `#[entry_point]` attribute.
 */
private predicate hasEntryPointAttr(Function f) {
  exists(Attr a |
    a = f.getAnAttr() and
    isEntryPointAttr(a)
  )
}

/**
 * Holds if function `f` matches a CosmWasm entry point signature pattern.
 * Matches standard entry point names with 3+ parameters.
 */
private predicate hasCosmWasmEntryPointSignature(Function f) {
  f.getName().getText() in [
      "instantiate", "execute", "query", "migrate", "sudo", "reply",
      "ibc_channel_open", "ibc_channel_connect", "ibc_channel_close",
      "ibc_packet_receive", "ibc_packet_ack", "ibc_packet_timeout"
    ] and
  f.getNumberOfParams() >= 2
}

/**
 * A CosmWasm smart contract entry point function.
 * Detected via `#[entry_point]` attribute or matching function signature.
 */
class CosmWasmEntryPoint extends Function {
  CosmWasmEntryPoint() {
    hasEntryPointAttr(this) or
    hasCosmWasmEntryPointSignature(this)
  }
}

/**
 * A CosmWasm `execute` entry point handler.
 * Receives `DepsMut`, `Env`, `MessageInfo`, and a message type.
 */
class ExecuteHandler extends CosmWasmEntryPoint {
  ExecuteHandler() {
    this.getName().getText() = "execute"
  }
}

/**
 * A CosmWasm `query` entry point handler.
 * Receives `Deps` (immutable), `Env`, and a message type.
 */
class QueryHandler extends CosmWasmEntryPoint {
  QueryHandler() {
    this.getName().getText() = "query"
  }
}

/**
 * A CosmWasm `instantiate` entry point handler.
 */
class InstantiateHandler extends CosmWasmEntryPoint {
  InstantiateHandler() {
    this.getName().getText() = "instantiate"
  }
}

/**
 * A CosmWasm `migrate` entry point handler.
 * Migration without authorization = full contract takeover.
 */
class MigrateHandler extends CosmWasmEntryPoint {
  MigrateHandler() {
    this.getName().getText() = "migrate"
  }
}

/**
 * A CosmWasm `reply` entry point handler for SubMsg callbacks.
 */
class ReplyHandler extends CosmWasmEntryPoint {
  ReplyHandler() {
    this.getName().getText() = "reply"
  }
}

/**
 * A CosmWasm IBC entry point handler.
 * Includes packet receive, ack, timeout, and channel lifecycle.
 */
class IbcEntryPoint extends CosmWasmEntryPoint {
  IbcEntryPoint() {
    this.getName().getText() in [
        "ibc_channel_open", "ibc_channel_connect", "ibc_channel_close",
        "ibc_packet_receive", "ibc_packet_ack", "ibc_packet_timeout"
      ]
  }
}
