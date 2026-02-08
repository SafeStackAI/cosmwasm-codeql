# Missing Address Validation

## Description
Using `Addr::unchecked()` to create addresses from user input bypasses validation, allowing malformed or malicious addresses to be stored. This can break contract logic that depends on valid bech32 addresses.

## Recommendation
Always validate user-provided address strings using `deps.api.addr_validate()` before storage or use. This ensures addresses conform to the chain's bech32 format.

## Example

### Vulnerable Code
```rust
pub fn execute_set_recipient(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    recipient: String,
) -> Result<Response, ContractError> {
    // No validation - accepts any string
    let recipient_addr = Addr::unchecked(recipient);

    CONFIG.update(deps.storage, |mut config| -> Result<_, ContractError> {
        config.recipient = recipient_addr;
        Ok(config)
    })?;

    Ok(Response::new())
}
```

### Fixed Code
```rust
pub fn execute_set_recipient(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    recipient: String,
) -> Result<Response, ContractError> {
    // Validate address format
    let recipient_addr = deps.api.addr_validate(&recipient)?;

    CONFIG.update(deps.storage, |mut config| -> Result<_, ContractError> {
        config.recipient = recipient_addr;
        Ok(config)
    })?;

    Ok(Response::new().add_attribute("recipient", recipient))
}
```

## References
- [CWE-20: Improper Input Validation](https://cwe.mitre.org/data/definitions/20.html)
- [CosmWasm Address Validation](https://docs.cosmwasm.com/docs/smart-contracts/validation/)
