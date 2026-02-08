# Unchecked Storage Unwrap

## Description
Calling `.unwrap()` on storage load operations creates panic vulnerabilities. If the expected key doesn't exist, the contract panics and the transaction fails, potentially locking funds or breaking contract functionality.

## Recommendation
Use the `?` operator to propagate errors or explicit error handling with pattern matching. Never use `.unwrap()` in production contract code.

## Example

### Vulnerable Code
```rust
pub fn execute_transfer(
    deps: DepsMut,
    info: MessageInfo,
    recipient: String,
    amount: Uint128,
) -> Result<Response, ContractError> {
    // Panics if sender has no balance entry
    let mut sender_balance = BALANCES.load(deps.storage, &info.sender).unwrap();

    sender_balance = sender_balance.checked_sub(amount)?;
    BALANCES.save(deps.storage, &info.sender, &sender_balance)?;

    Ok(Response::new())
}
```

### Fixed Code
```rust
pub fn execute_transfer(
    deps: DepsMut,
    info: MessageInfo,
    recipient: String,
    amount: Uint128,
) -> Result<Response, ContractError> {
    // Proper error handling with ?
    let mut sender_balance = BALANCES.load(deps.storage, &info.sender)?;

    sender_balance = sender_balance.checked_sub(amount)
        .map_err(|_| ContractError::InsufficientFunds {})?;

    BALANCES.save(deps.storage, &info.sender, &sender_balance)?;

    Ok(Response::new())
}
```

## References
- [CWE-252: Unchecked Return Value](https://cwe.mitre.org/data/definitions/252.html)
- [CosmWasm Storage Patterns](https://docs.cosmwasm.com/docs/smart-contracts/state/)
