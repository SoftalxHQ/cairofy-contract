// All the structs for the project
use starknet::ContractAddress;

#[derive(Clone, Copy, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct Song {
    pub name: felt252,
    pub ipfs_hash: felt252,
    pub preview_ipfs_hash: felt252,
    pub price: u256,
    pub owner: ContractAddress,
    pub for_sale: bool,
}

