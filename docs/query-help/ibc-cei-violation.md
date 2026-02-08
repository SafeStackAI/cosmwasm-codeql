# IBC CEI Violation

## Description
IBC handlers that modify state before dispatching messages violate the Checks-Effects-Interactions (CEI) pattern. This creates reentrancy risks where message execution can call back into the contract before state is finalized, potentially allowing double-spending or state corruption.

## Recommendation
Separate state changes from message dispatch in IBC handlers. Use reply handlers to finalize state only after messages execute successfully, or ensure all state changes complete before constructing response messages.

## Example

### Vulnerable Code
```rust
pub fn ibc_packet_receive(
    deps: DepsMut,
    _env: Env,
    msg: IbcPacketReceiveMsg,
) -> Result<IbcReceiveResponse, ContractError> {
    let transfer: TransferMsg = from_binary(&msg.packet.data)?;

    // State change before message dispatch - CEI violation
    let mut balance = BALANCES.load(deps.storage, &transfer.recipient)?;
    balance = balance.checked_add(transfer.amount)?;
    BALANCES.save(deps.storage, &transfer.recipient, &balance)?;

    // Message dispatch could reenter
    let exec_msg = WasmMsg::Execute {
        contract_addr: transfer.recipient.to_string(),
        msg: to_binary(&ExecuteMsg::OnReceive {})?,
        funds: vec![],
    };

    Ok(IbcReceiveResponse::new().add_message(exec_msg))
}
```

### Fixed Code
```rust
pub fn ibc_packet_receive(
    deps: DepsMut,
    _env: Env,
    msg: IbcPacketReceiveMsg,
) -> Result<IbcReceiveResponse, ContractError> {
    let transfer: TransferMsg = from_binary(&msg.packet.data)?;

    // Use submessage with reply to handle state after execution
    let exec_msg = WasmMsg::Execute {
        contract_addr: transfer.recipient.to_string(),
        msg: to_binary(&ExecuteMsg::OnReceive {})?,
        funds: vec![],
    };

    let submsg = SubMsg::reply_on_success(exec_msg, TRANSFER_REPLY_ID);

    Ok(IbcReceiveResponse::new().add_submessage(submsg))
}

#[cfg_attr(not(feature = "library"), entry_point)]
pub fn reply(deps: DepsMut, _env: Env, msg: Reply) -> Result<Response, ContractError> {
    // Update state only after successful execution
    if msg.id == TRANSFER_REPLY_ID {
        let transfer = PENDING_TRANSFER.load(deps.storage)?;
        let mut balance = BALANCES.load(deps.storage, &transfer.recipient)?;
        balance = balance.checked_add(transfer.amount)?;
        BALANCES.save(deps.storage, &transfer.recipient, &balance)?;
    }
    Ok(Response::new())
}
```

## References
- [CWE-841: Improper Enforcement of Behavioral Workflow](https://cwe.mitre.org/data/definitions/841.html)
- [CosmWasm IBC Documentation](https://docs.cosmwasm.com/docs/ibc/)
