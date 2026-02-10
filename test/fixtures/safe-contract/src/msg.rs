use cosmwasm_schema::cw_serde;
use cosmwasm_std::Uint128;

#[cw_serde]
pub struct InstantiateMsg {
    pub admin: String,
}

#[cw_serde]
pub enum ExecuteMsg {
    UpdateConfig { new_admin: String },
    Mint { amount: Uint128, recipient: String },
    Withdraw { amount: Uint128 },
    FinalizeProposal { proposal_id: u64 },
}

#[cw_serde]
pub enum QueryMsg {
    Config {},
}

#[cw_serde]
pub struct MigrateMsg {}
