use starknet::ContractAddress;
use super::interface::ISongMarketplace;

#[derive(Drop, Serde)]
struct Song {
    name: felt252,
    ipfs_hash: felt252,
    preview_ipfs_hash: felt252,
    price: u256,
    owner: ContractAddress,
    for_sale: bool,
}

#[starknet::contract]
mod SongMarketplace {
    use starknet::ContractAddress;
    use super::{ISongMarketplace, Song};


    #[storage]
    struct Storage {
        songs: LegacyMap<u64, Song>,
        song_count: u64,
        user_songs: LegacyMap<(ContractAddress, u64), bool>,
        user_song_count: LegacyMap<ContractAddress, u64>,
        user_song_ids: LegacyMap<(ContractAddress, u64), u64>,
    }

    #[constructor]
    // fn constructor(ref self: ContractState) {
    //     self.song_count.write(0);
    // }

    #[external(v0)]
    impl SongMarketplaceImpl of ISongMarketplace<ContractState> {// TODO: Implement function to register a new song
    // fn register_song(...) { ... }

    // TODO: Implement function to get detailed song info
    // fn get_song_info(...) -> (...) { ... }

    // TODO: Implement function to update the price of a song
    // fn update_song_price(...) { ... }

    // TODO: Implement function to get the preview hash of a song
    // fn get_preview(...) -> felt252 { ... }

    // TODO: Implement function to buy a song and transfer ownership
    // fn buy_song(...) -> felt252 { ... }

    // TODO: Implement function to fetch songs owned by a specific user
    // fn get_user_songs(...) -> Array<u64> { ... }

    // TODO: Implement function to check if a user is the owner of a song
    // fn is_song_owner(...) -> bool { ... }
    }
}
