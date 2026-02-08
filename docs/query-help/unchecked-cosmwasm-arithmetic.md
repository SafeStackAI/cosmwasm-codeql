# Unchecked CosmWasm Arithmetic

## Description
Using standard arithmetic operators (+, -, *, /) on CosmWasm integer types (Uint128, Uint256, Uint64) can cause silent overflow/underflow without panicking, leading to incorrect balances and state corruption.

## Recommendation
Always use checked arithmetic methods (`checked_add`, `checked_sub`, `checked_mul`, `checked_div`) which return errors on overflow/underflow instead of wrapping.

## Example

### Vulnerable Code
```rust
pub fn execute_deposit(
    deps: DepsMut,
    info: MessageInfo,
    amount: Uint128,
) -> Result<Response, ContractError> {
    let mut balance = BALANCES.load(deps.storage, &info.sender)?;

    // Vulnerable: overflow wraps silently
    balance = balance + amount;

    BALANCES.save(deps.storage, &info.sender, &balance)?;
    Ok(Response::new())
}
```

### Fixed Code
```rust
pub fn execute_deposit(
    deps: DepsMut,
    info: MessageInfo,
    amount: Uint128,
) -> Result<Response, ContractError> {
    let mut balance = BALANCES.load(deps.storage, &info.sender)?;

    // Safe: returns error on overflow
    balance = balance.checked_add(amount)
        .map_err(|_| ContractError::Overflow {})?;

    BALANCES.save(deps.storage, &info.sender, &balance)?;
    Ok(Response::new())
}
```

## References
- [CWE-190: Integer Overflow or Wraparound](https://cwe.mitre.org/data/definitions/190.html)
- [CosmWasm Math Documentation](https://docs.rs/cosmwasm-std/latest/cosmwasm_std/struct.Uint128.html)
