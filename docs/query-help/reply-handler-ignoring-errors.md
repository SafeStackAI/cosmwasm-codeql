# Reply Handler Ignoring Errors

## Description
Reply handlers that don't inspect the `Reply.result` field miss critical error information from submessage execution. Ignoring failures can lead to inconsistent state where the contract assumes an operation succeeded when it actually failed.

## Recommendation
Always match on `msg.result` in reply handlers. Handle both success and error cases explicitly, updating state or reverting operations based on the outcome.

## Example

### Vulnerable Code
```rust
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn reply(deps: DepsMut, _env: Env, msg: Reply) -> Result<Response, ContractError> {
    match msg.id {
        TRANSFER_REPLY_ID => {
            // Ignores msg.result - assumes success
            let mut state = STATE.load(deps.storage)?;
            state.transfer_completed = true;
            STATE.save(deps.storage, &state)?;

            Ok(Response::new().add_attribute("transfer", "completed"))
        }
        _ => Err(ContractError::UnknownReplyId {}),
    }
}
```

### Fixed Code
```rust
use cosmwasm_std::SubMsgResult;

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn reply(deps: DepsMut, _env: Env, msg: Reply) -> Result<Response, ContractError> {
    match msg.id {
        TRANSFER_REPLY_ID => {
            match msg.result {
                SubMsgResult::Ok(_) => {
                    // Only update state on success
                    let mut state = STATE.load(deps.storage)?;
                    state.transfer_completed = true;
                    STATE.save(deps.storage, &state)?;

                    Ok(Response::new().add_attribute("transfer", "completed"))
                }
                SubMsgResult::Err(err) => {
                    // Handle error case - revert or log
                    let mut state = STATE.load(deps.storage)?;
                    state.transfer_failed = true;
                    state.last_error = Some(err.clone());
                    STATE.save(deps.storage, &state)?;

                    Err(ContractError::TransferFailed { reason: err })
                }
            }
        }
        _ => Err(ContractError::UnknownReplyId {}),
    }
}
```

## References
- [CWE-390: Detection of Error Condition Without Action](https://cwe.mitre.org/data/definitions/390.html)
- [CosmWasm Reply Handling](https://docs.cosmwasm.com/docs/smart-contracts/submessages/)
