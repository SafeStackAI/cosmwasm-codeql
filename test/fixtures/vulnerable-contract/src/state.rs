use cosmwasm_std::{Addr, Uint128};
use cw_storage_plus::{Item, Map};

pub struct Config {
    pub admin: Addr,
    pub total_supply: Uint128,
}

pub const CONFIG: Item<Config> = Item::new("config");
pub const BALANCES: Map<&Addr, Uint128> = Map::new("bal");
// Q7: Storage key collision — same key "bal" as BALANCES
pub const BACKUP: Item<Vec<u8>> = Item::new("bal");
