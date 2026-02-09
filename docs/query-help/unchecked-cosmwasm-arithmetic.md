# Unchecked CosmWasm Arithmetic

## Description
Using standard arithmetic operators (+, -, *, /) on CosmWasm integer types (Uint128, Uint256, Uint64) can cause silent overflow/underflow without panicking, leading to incorrect balances and state corruption.

This query focuses on arithmetic operations in storage and response contexts (where user-controlled values are most likely to cause harm). It excludes dependency code, build artifacts, and const/static expressions to reduce false positives.

Note: cosmwasm-std >= 1.0 Uint128 arithmetic operations are safe (panic on overflow), so false positives may occur with recent versions.

## Recommendation
Always use checked arithmetic methods (`checked_add`, `checked_sub`, `checked_mul`, `checked_div`) which return errors on overflow/underflow instead of wrapping. If using cosmwasm-std >= 1.0, consider suppressing this query for Uint128 with inline comments.

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
