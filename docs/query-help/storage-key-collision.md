# Storage Key Collision

## Description
Multiple storage items (Item, Map) using the same string key cause data corruption. When different data structures share a storage namespace, writes to one structure overwrite data in the other, leading to unpredictable contract behavior.

## Recommendation
Ensure every storage declaration uses a unique string key. Establish a naming convention (e.g., prefixing with type name) to prevent collisions.

## Example

### Vulnerable Code
```rust
use cw_storage_plus::{Item, Map};

// Both use "config" key - collision!
const CONFIG: Item<Config> = Item::new("config");
const USER_CONFIG: Map<&Addr, UserConfig> = Map::new("config");

pub fn execute_save_config(deps: DepsMut) -> Result<Response, ContractError> {
    CONFIG.save(deps.storage, &Config::default())?;
    // This overwrites CONFIG data due to key collision
    USER_CONFIG.save(deps.storage, &Addr::unchecked("user"), &UserConfig::default())?;
    Ok(Response::new())
}
```

### Fixed Code
```rust
use cw_storage_plus::{Item, Map};

// Unique keys prevent collision
const CONFIG: Item<Config> = Item::new("config");
const USER_CONFIG: Map<&Addr, UserConfig> = Map::new("user_config");

pub fn execute_save_config(deps: DepsMut) -> Result<Response, ContractError> {
    CONFIG.save(deps.storage, &Config::default())?;
    // Safe: different storage namespaces
    USER_CONFIG.save(deps.storage, &Addr::unchecked("user"), &UserConfig::default())?;
    Ok(Response::new())
}
```

## References
- [CosmWasm Storage Documentation](https://docs.cosmwasm.com/docs/smart-contracts/state/)
- [cw-storage-plus Documentation](https://docs.rs/cw-storage-plus/latest/cw_storage_plus/)
