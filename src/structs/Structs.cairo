// All the structs for the project
use starknet::ContractAddress;

#[derive(Clone, Copy, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct Song {
    pub id: u64,
    pub name: felt252,
    pub ipfs_hash: felt252,
    pub preview_ipfs_hash: felt252,
    pub price: u256,
    pub owner: ContractAddress,
    pub for_sale: bool,
}

#[derive(Clone, Copy, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct UserSubscription {
    pub start_date: u64,
    pub expiry_date: u64,
    pub user: ContractAddress,
    pub subscription_id: u64,
    pub user_id: u256,
}

#[derive(Clone, Copy, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct User {
    pub user: ContractAddress,
    pub has_subscribed: bool,
    pub user_id: u256,
}
