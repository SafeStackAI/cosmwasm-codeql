# Missing Execute Authorization

## Description
Execute handlers that modify contract state without verifying the caller's identity allow unauthorized users to perform privileged operations. This violates access control principles and can lead to complete contract compromise.

## Recommendation
Always verify `info.sender` against authorized addresses (admin, owner, or whitelist) before allowing state modifications in execute handlers.

## Example

### Vulnerable Code
```rust
pub fn execute_update_config(
    deps: DepsMut,
    _env: Env,
    _info: MessageInfo,
    new_config: Config,
) -> Result<Response, ContractError> {
    // Missing authorization check - anyone can update config
    CONFIG.save(deps.storage, &new_config)?;
    Ok(Response::new().add_attribute("action", "update_config"))
}
```

### Fixed Code
```rust
pub fn execute_update_config(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    new_config: Config,
) -> Result<Response, ContractError> {
    let config = CONFIG.load(deps.storage)?;

    // Verify sender is admin
    if info.sender != config.admin {
        return Err(ContractError::Unauthorized {});
    }

    CONFIG.save(deps.storage, &new_config)?;
    Ok(Response::new().add_attribute("action", "update_config"))
}
```

## References
- [CWE-862: Missing Authorization](https://cwe.mitre.org/data/definitions/862.html)
- [CosmWasm Security Best Practices](https://docs.cosmwasm.com/docs/smart-contracts/best-practices/)
