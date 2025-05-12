#[derive(Drop, starknet::Event)]
pub struct Song_Registered {
    pub song_id: u64,
    pub name: felt252,
    pub ipfs_hash: felt252,
    pub preview_ipfs_hash: felt252,
    pub price: u256,
    pub for_sale: bool,
}

#[derive(Drop, starknet::Event)]
pub struct SongPriceUpdated {
    pub song_id: u64,
    pub name: felt252,
    pub ipfs_hash: felt252,
    pub preview_ipfs_hash: felt252,
    pub updated_price: u256,
    pub for_sale: bool,
}
