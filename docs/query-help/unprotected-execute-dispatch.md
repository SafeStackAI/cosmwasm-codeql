# Unprotected Execute Dispatch

## Description
Execute message dispatch patterns that route to state-modifying handlers without authorization checks in the dispatcher or handler create security gaps. Attackers can invoke privileged operations by crafting specific message types.

## Recommendation
Add authorization checks either in the dispatcher before routing or within each privileged handler function. Prefer handler-level checks for clarity.

## Example

### Vulnerable Code
```rust
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn execute(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    msg: ExecuteMsg,
) -> Result<Response, ContractError> {
    match msg {
        ExecuteMsg::UpdateConfig { config } => execute_update_config(deps, env, info, config),
        ExecuteMsg::Withdraw { amount } => execute_withdraw(deps, env, info, amount),
        // No authorization in dispatcher or handlers
    }
}
```

### Fixed Code
```rust
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn execute(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    msg: ExecuteMsg,
) -> Result<Response, ContractError> {
    match msg {
        ExecuteMsg::UpdateConfig { config } => {
            ensure_admin(deps.as_ref(), &info)?;
            execute_update_config(deps, env, info, config)
        }
        ExecuteMsg::Withdraw { amount } => {
            ensure_admin(deps.as_ref(), &info)?;
            execute_withdraw(deps, env, info, amount)
        }
    }
}

fn ensure_admin(deps: Deps, info: &MessageInfo) -> Result<(), ContractError> {
    let config = CONFIG.load(deps.storage)?;
    if info.sender != config.admin {
        return Err(ContractError::Unauthorized {});
    }
    Ok(())
}
```

## References
- [CWE-285: Improper Authorization](https://cwe.mitre.org/data/definitions/285.html)
- [CosmWasm Message Handling](https://docs.cosmwasm.com/docs/smart-contracts/message/)
