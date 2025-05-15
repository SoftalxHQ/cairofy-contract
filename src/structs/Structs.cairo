// All the structs for the project
use starknet::ContractAddress;
use starknet::storage::{MutableVecTrait, Vec};

#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct Song {
    pub id: u64,
    pub name: ByteArray,
    pub ipfs_hash: ByteArray,
    pub preview_ipfs_hash: ByteArray,
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

#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct ArtisteMetadata {
    pub name: felt252,
    pub description: ByteArray,
    pub contract_address: ContractAddress,
    pub amount_earned: u64,
    pub profile_image_uri: felt252,
    pub creation_date: u64,
    pub total_followers: u64,
    pub total_songs: u16,
    pub verified: bool,
    pub total_sales: u64,
    pub highest_sale: u64,
}
#[derive(Clone, Copy, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct User {
    pub user_name: felt252,
    pub user: ContractAddress,
    pub has_subscribed: bool,
    pub user_id: u256,
}

#[derive(Clone, Copy, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct PlatformStats {
    pub total_suscribers: u64,
    pub platform_revenue: u256,
    // total_songs: u64,
}

#[derive(Clone, Debug, Drop, PartialEq, Serde, starknet::Store)]
pub struct SongStats {
    pub song_id: u64,
    pub name: ByteArray,
    pub play_count: u64,
    pub revenue_generated: u64,
}

#[derive(Clone, Debug, Drop, PartialEq, Serde)]
pub struct RevenueReport {
    revenue_by_artist: Array<(u64, u64)>,
}
