use cosmwasm_std::{
    entry_point, Addr, DepsMut, Env, MessageInfo, Response, Uint128,
};
use crate::error::ContractError;
use crate::msg::{ExecuteMsg, InstantiateMsg, MigrateMsg};
use crate::state::{Config, CONFIG};

#[entry_point]
pub fn instantiate(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    _msg: InstantiateMsg,
) -> Result<Response, ContractError> {
    let config = Config {
        admin: info.sender.clone(),
        total_supply: Uint128::zero(),
    };
    CONFIG.save(deps.storage, &config)?;
    Ok(Response::new())
}

#[entry_point]
pub fn execute(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    msg: ExecuteMsg,
) -> Result<Response, ContractError> {
    match msg {
        ExecuteMsg::UpdateConfig { new_admin } => {
            execute_update_config(deps, env, info, new_admin)
        }
        ExecuteMsg::Mint { amount, recipient } => {
            execute_mint(deps, env, info, amount, recipient)
        }
    }
}

// Q1: Missing authorization — writes state without sender check
// Q6: Missing address validation — uses Addr::unchecked
fn execute_update_config(
    deps: DepsMut,
    _env: Env,
    _info: MessageInfo,
    new_admin: String,
) -> Result<Response, ContractError> {
    CONFIG.save(
        deps.storage,
        &Config {
            admin: Addr::unchecked(new_admin),
            total_supply: Uint128::zero(),
        },
    )?;
    Ok(Response::new())
}

// Q1: Missing authorization on mint
// Q4: Unchecked arithmetic on Uint128
// Q5: Unchecked unwrap on storage load
fn execute_mint(
    deps: DepsMut,
    _env: Env,
    _info: MessageInfo,
    amount: Uint128,
    _recipient: String,
) -> Result<Response, ContractError> {
    let mut config = CONFIG.load(deps.storage).unwrap();
    config.total_supply = config.total_supply + amount;
    CONFIG.save(deps.storage, &config)?;
    Ok(Response::new())
}

// Q2: Missing migration authorization
#[entry_point]
pub fn migrate(
    _deps: DepsMut,
    _env: Env,
    _msg: MigrateMsg,
) -> Result<Response, ContractError> {
    Ok(Response::new())
}
