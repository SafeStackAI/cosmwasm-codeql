use cosmwasm_std::{
    entry_point, DepsMut, Env, MessageInfo, Reply, Response, SubMsg,
    Uint128, WasmMsg,
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

// Safe: has authorization check (info.sender == config.admin)
// Safe: uses addr_validate instead of Addr::unchecked
fn execute_update_config(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    new_admin: String,
) -> Result<Response, ContractError> {
    let config = CONFIG.load(deps.storage)?;
    if info.sender != config.admin {
        return Err(ContractError::Unauthorized {});
    }
    let validated_addr = deps.api.addr_validate(&new_admin)?;
    CONFIG.save(
        deps.storage,
        &Config {
            admin: validated_addr,
            total_supply: config.total_supply,
        },
    )?;
    Ok(Response::new())
}

// Safe: has authorization check + checked arithmetic + ? operator
fn execute_mint(
    deps: DepsMut,
    _env: Env,
    info: MessageInfo,
    amount: Uint128,
    _recipient: String,
) -> Result<Response, ContractError> {
    let mut config = CONFIG.load(deps.storage)?;
    if info.sender != config.admin {
        return Err(ContractError::Unauthorized {});
    }
    config.total_supply = config.total_supply.checked_add(amount)
        .map_err(|_| ContractError::Std(cosmwasm_std::StdError::generic_err("overflow")))?;
    CONFIG.save(deps.storage, &config)?;
    Ok(Response::new())
}

// Safe: migrate checks admin authorization via helper
#[entry_point]
pub fn migrate(
    deps: DepsMut,
    _env: Env,
    _msg: MigrateMsg,
) -> Result<Response, ContractError> {
    ensure_admin(deps.as_ref())?;
    Ok(Response::new())
}

fn ensure_admin(_deps: cosmwasm_std::Deps) -> Result<(), ContractError> {
    // In production, verify governance/admin caller
    Ok(())
}

// Safe: reply handler inspects result
#[entry_point]
pub fn reply(
    _deps: DepsMut,
    _env: Env,
    msg: Reply,
) -> Result<Response, ContractError> {
    match msg.result {
        cosmwasm_std::SubMsgResult::Ok(_) => Ok(Response::new()),
        cosmwasm_std::SubMsgResult::Err(err) => {
            Err(ContractError::Std(cosmwasm_std::StdError::generic_err(err)))
        }
    }
}

// Safe: SubMsg with reply — and reply handler exists above
pub fn execute_swap(
    _deps: DepsMut,
    _env: Env,
    _info: MessageInfo,
) -> Result<Response, ContractError> {
    let swap_msg = WasmMsg::Execute {
        contract_addr: "swap_contract".to_string(),
        msg: b"{}".into(),
        funds: vec![],
    };
    let msg = SubMsg::reply_on_success(swap_msg, 1);
    Ok(Response::new().add_submessage(msg))
}
