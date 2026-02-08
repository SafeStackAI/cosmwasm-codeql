# SubMsg Without Reply Handler

## Description
Creating SubMsg instances with reply callbacks (reply_on_success, reply_on_error, reply_always) without implementing a corresponding reply entry point causes transaction failures when the submessage completes. The runtime cannot invoke the missing handler.

## Recommendation
Always implement a reply entry point when using SubMsg with reply callbacks. Match on reply IDs to handle different submessage results appropriately.

## Example

### Vulnerable Code
```rust
pub fn execute_transfer(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
) -> Result<Response, ContractError> {
    let msg = WasmMsg::Execute {
        contract_addr: "target_contract".to_string(),
        msg: to_binary(&ExecuteMsg::Process {})?,
        funds: vec![],
    };

    // Creates submessage with reply callback but no reply handler exists
    let submsg = SubMsg::reply_on_success(msg, 1);

    Ok(Response::new().add_submessage(submsg))
}

// Missing: reply entry point
```

### Fixed Code
```rust
const TRANSFER_REPLY_ID: u64 = 1;

pub fn execute_transfer(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
) -> Result<Response, ContractError> {
    let msg = WasmMsg::Execute {
        contract_addr: "target_contract".to_string(),
        msg: to_binary(&ExecuteMsg::Process {})?,
        funds: vec![],
    };

    let submsg = SubMsg::reply_on_success(msg, TRANSFER_REPLY_ID);

    Ok(Response::new().add_submessage(submsg))
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn reply(deps: DepsMut, _env: Env, msg: Reply) -> Result<Response, ContractError> {
    match msg.id {
        TRANSFER_REPLY_ID => handle_transfer_reply(deps, msg),
        _ => Err(ContractError::UnknownReplyId { id: msg.id }),
    }
}

fn handle_transfer_reply(deps: DepsMut, msg: Reply) -> Result<Response, ContractError> {
    // Process reply result
    Ok(Response::new().add_attribute("reply_handled", "transfer"))
}
```

## References
- [CosmWasm Submessages Documentation](https://docs.cosmwasm.com/docs/smart-contracts/submessages/)
- [Reply Handler Pattern](https://docs.cosmwasm.com/tutorials/submessages/)
