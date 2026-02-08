use cosmwasm_std::{
    entry_point, BankMsg, Coin, DepsMut, Env,
    IbcBasicResponse, IbcPacketTimeoutMsg, Reply, Response, SubMsg,
    WasmMsg,
};
use crate::error::ContractError;
use crate::state::CONFIG;

// Q8: IBC CEI violation — state change + message dispatch
#[entry_point]
pub fn ibc_packet_timeout(
    deps: DepsMut,
    _env: Env,
    _msg: IbcPacketTimeoutMsg,
) -> Result<IbcBasicResponse, ContractError> {
    // State change before interaction (CEI violation)
    CONFIG.remove(deps.storage);
    let refund = BankMsg::Send {
        to_address: "sender".to_string(),
        amount: vec![Coin::new(100u128, "uatom")],
    };
    Ok(IbcBasicResponse::new().add_message(refund))
}

// Q9: SubMsg with reply but no reply handler exists
pub fn execute_swap(
    _deps: DepsMut,
    _env: Env,
    _info: cosmwasm_std::MessageInfo,
) -> Result<Response, ContractError> {
    let swap_msg = WasmMsg::Execute {
        contract_addr: "swap_contract".to_string(),
        msg: b"{}".into(),
        funds: vec![],
    };
    let msg = SubMsg::reply_on_success(swap_msg, 1);
    Ok(Response::new().add_submessage(msg))
}
