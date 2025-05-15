#[derive(Drop, Clone, starknet::Event)]
pub struct Song_Registered {
    pub song_id: u64,
    pub name: ByteArray,
    pub ipfs_hash: ByteArray,
    pub preview_ipfs_hash: ByteArray,
    pub price: u256,
    pub for_sale: bool,
}

#[derive(Drop, Clone, starknet::Event)]
pub struct SongPriceUpdated {
    pub song_id: u64,
    pub ipfs_hash: ByteArray,
    pub preview_ipfs_hash: ByteArray,
    pub updated_price: u256,
    pub for_sale: bool,
}

#[derive(Drop, Clone, starknet::Event)]
pub struct Artiste_Created {
    pub name: felt252,
    pub description: ByteArray,
    pub creation_date: u64,
}
