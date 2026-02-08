# Missing Migrate Authorization

## Description
Migration handlers without authorization checks allow any address to upgrade the contract, potentially replacing legitimate logic with malicious code. This is a critical vulnerability in upgradeable contracts.

## Recommendation
Implement admin verification in the migrate entry point before allowing contract upgrades. Store admin address during instantiation.

## Example

### Vulnerable Code
```rust
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn migrate(
    deps: DepsMut,
    _env: Env,
    _msg: MigrateMsg,
) -> Result<Response, ContractError> {
    // Missing authorization - anyone can migrate the contract
    set_contract_version(deps.storage, CONTRACT_NAME, CONTRACT_VERSION)?;
    Ok(Response::default())
}
```

### Fixed Code
```rust
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn migrate(
    deps: DepsMut,
    _env: Env,
    msg: MigrateMsg,
) -> Result<Response, ContractError> {
    let config = CONFIG.load(deps.storage)?;

    // Verify only admin can migrate
    if msg.sender != config.admin {
        return Err(ContractError::Unauthorized {});
    }

    set_contract_version(deps.storage, CONTRACT_NAME, CONTRACT_VERSION)?;
    Ok(Response::default())
}
```

## References
- [CWE-862: Missing Authorization](https://cwe.mitre.org/data/definitions/862.html)
- [CosmWasm Contract Migration](https://docs.cosmwasm.com/docs/smart-contracts/migration/)
