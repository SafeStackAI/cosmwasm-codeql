# Unprotected Execute Dispatch

## Description
Execute message dispatch patterns that route to state-modifying handlers without authorization checks in the dispatcher or handler create security gaps. Attackers can invoke privileged operations by crafting specific message types.

This query detects match expressions on the ExecuteMsg parameter within execute handlers and reports any branches that do not perform authorization checks before calling the handler function.

## Recommendation
Add authorization checks at the execute-handler level (before the match) or at the dispatcher branch level (for each sensitive operation). Handler-level checks are preferred for consistency. Use established auth patterns: `info.sender` comparisons, assert/ensure macros, helper methods (is_admin, can_execute, assert_owner), or dedicated authorization functions.

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
