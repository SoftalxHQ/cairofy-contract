use cairofy_contract::contracts::Cairofy::CairofyV0;
use cairofy_contract::events::Events::{SongPriceUpdated, Song_Registered};
use cairofy_contract::interfaces::ICairofy::{ICairofyDispatcher, ICairofyDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address, test_address,
};
use core::array::Array;
use starknet::{ContractAddress, contract_address_const};

fn OWNER() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn NON_OWNER() -> ContractAddress {
    contract_address_const::<'non_owner'>()
}

fn TEST_OWNER1() -> ContractAddress {
    contract_address_const::<'test_owner1'>()
}

fn TEST_OWNER2() -> ContractAddress {
    contract_address_const::<'test_owner2'>()
}

fn TEST_OWNER3() -> ContractAddress {
    contract_address_const::<'test_owner3'>()
}

fn deploy_contract() -> ICairofyDispatcher {
    let contract_class = declare("CairofyV0").unwrap().contract_class();
    let (cairofy_address, _) = contract_class.deploy(@array![OWNER().into()]).unwrap();

    let dispatcher = ICairofyDispatcher { contract_address: cairofy_address };

    dispatcher
}

fn register_default_song() -> u64 {
    let dispatcher = deploy_contract();
    let song_id = dispatcher.register_song('name', 'hashin song', 'preview hash', 30, true);
    song_id
}
#[test]
fn test_register_song() {
    let dispatcher = deploy_contract();
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    assert(song_id == 1, 'Song ID should be 1');

    let song = dispatcher.get_song_info(song_id);
    assert(song.name == 'why me', 'Song name should be "why me"');
    assert(song.ipfs_hash == 'i dont know', 'wrong ipfs hash');
    assert(song.preview_ipfs_hash == 'cohort 4', 'wrong preview ipfs hash');
    assert(song.price == 20, 'wrong price');
}

#[test]
fn test_register_song_event() {
    let dispatcher = deploy_contract();
    let mut spy = spy_events();

    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    assert(song_id == 1, 'Song ID should be 1');

    let song = dispatcher.get_song_info(song_id);
    assert(song.name == 'why me', 'Song name should be "why me"');
    assert(song.ipfs_hash == 'i dont know', 'wrong ipfs hash');
    assert(song.preview_ipfs_hash == 'cohort 4', 'wrong preview ipfs hash');
    assert(song.price == 20, 'wrong price');

    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    CairofyV0::Event::Song_Registered(
                        Song_Registered {
                            song_id: song_id,
                            name: song.name,
                            ipfs_hash: song.ipfs_hash,
                            preview_ipfs_hash: song.preview_ipfs_hash,
                            price: song.price,
                            for_sale: song.for_sale,
                        },
                    ),
                ),
            ],
        )
}

#[test]
#[should_panic(expect: "Song name cannot be empty")]
fn test_register_empty_song_name() {
    let dispatcher = deploy_contract();
    dispatcher.register_song('', 'i dont know', 'cohort 4', 20, true);
}
#[test]
#[should_panic(expect: "Your song hash cannot be empty")]
fn test_register_empty_song_hash() {
    let dispatcher = deploy_contract();
    dispatcher.register_song('why me', '', 'cohort 4', 20, true);
}
#[test]
#[should_panic(expect: "Your song preview hash cannot be empty")]
fn test_register_empty_preview_song_hash() {
    let dispatcher = deploy_contract();
    dispatcher.register_song('why me', 'i dont know', '', 20, true);
}
#[test]
#[should_panic(expect: "Price must be greater than 0")]
fn test_register_song_zero_price() {
    let dispatcher = deploy_contract();
    dispatcher.register_song('why me', 'i dont know', 'cohort 4', 0, true);
}

#[test]
fn test_update_song_price() {
    let dispatcher = deploy_contract();
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 500);
    let song = dispatcher.get_song_info(song_id);
    assert(song.price == 500, 'wrong price');
    assert(song.for_sale, 'song should be for sale');
    assert(song.name == 'why me', 'Song name should be "why me"');
    assert(song.ipfs_hash == 'i dont know', 'wrong ipfs hash');
    assert(song.preview_ipfs_hash == 'cohort 4', 'wrong preview ipfs hash');
}

#[test]
#[should_panic(expect: "Song ID does not exist")]
fn test_update_song_price_invalid_ID() {
    let dispatcher = deploy_contract();
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(10, 500);
}

#[test]
#[should_panic(expect: "Price must be greater than 0")]
fn test_update_song_price_invalid_price() {
    let dispatcher = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());

    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 0);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_update_song_price_owner() {
    let dispatcher = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());

    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 20);
    stop_cheat_caller_address(dispatcher.contract_address);
    let song = dispatcher.get_song_info(song_id);
    assert(song.price == 20, 'wrong price');
    assert(song.for_sale, 'song should be for sale');
    assert(song.name == 'why me', 'Song name should be "why me"');
    assert(song.ipfs_hash == 'i dont know', 'wrong ipfs hash');
    assert(song.preview_ipfs_hash == 'cohort 4', 'wrong preview ipfs hash');
}
#[test]
#[should_panic(expect: "Only the owner can update the song price")]
fn test_update_song_price_non_owner() {
    let dispatcher = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());

    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 0);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_update_song_price_event() {
    let dispatcher = deploy_contract();
    let mut spy = spy_events();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 500);
    let song = dispatcher.get_song_info(song_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    assert(song.price == 500, 'wrong price');
    assert(song.for_sale, 'song should be for sale');
    assert(song.name == 'why me', 'Song name should be "why me"');
    assert(song.ipfs_hash == 'i dont know', 'wrong ipfs hash');
    assert(song.preview_ipfs_hash == 'cohort 4', 'wrong preview ipfs hash');

    spy
        .assert_emitted(
            @array![
                (
                    dispatcher.contract_address,
                    CairofyV0::Event::SongPriceUpdated(
                        SongPriceUpdated {
                            song_id: song_id,
                            name: song.name,
                            ipfs_hash: song.ipfs_hash,
                            preview_ipfs_hash: song.preview_ipfs_hash,
                            updated_price: song.price,
                            for_sale: song.for_sale,
                        },
                    ),
                ),
            ],
        )
}

#[test]
#[should_panic(expect: "Song is not for sale")]
fn test_buy_song_not_for_sale() {
    let dispatcher = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher
        .register_song('tirin tirin tirin', 'i dont know', 'cohort 4', 20, false);

    let old_owner = dispatcher.get_song_info(song_id).owner;
    assert(old_owner == TEST_OWNER1(), 'wrong owner');

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER2());

    dispatcher.buy_song(song_id);
}

#[test]
fn test_buy_song() {
    let dispatcher = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher
        .register_song('tirin tirin tirin', 'i dont know', 'cohort 4', 20, true);

    let old_owner = dispatcher.get_song_info(song_id).owner;
    println!("old owner: {:?}", old_owner);
    assert(old_owner == TEST_OWNER1(), 'wrong owner');

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER2());

    dispatcher.buy_song(song_id);
    let new_owner = dispatcher.get_song_info(song_id).owner;
    println!("new owner: {:?}", new_owner);
    assert(new_owner == TEST_OWNER2(), 'buy failed');
}

#[test]
#[should_panic(expect: "You can't buy your own song")]
fn test_buy_song_by_owner() {
    let dispatcher = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher
        .register_song('tirin tirin tirin', 'i dont know', 'cohort 4', 20, true);

    let old_owner = dispatcher.get_song_info(song_id).owner;
    assert(old_owner == TEST_OWNER1(), 'wrong owner');

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    dispatcher.buy_song(song_id);
    let new_owner = dispatcher.get_song_info(song_id).owner;
    assert(new_owner == TEST_OWNER2(), 'buy failed');
}

// CaxtonStone Start
#[test]
fn test_get_user_songs_empty() {
    let dispatcher = deploy_contract();

    let user_felt: felt252 = 0x12345.into();
    let user: ContractAddress = user_felt.try_into().unwrap();
    // Get songs for a user who hasn't registered any
    let songs = dispatcher.get_user_songs(user);

    // Check that the returned array is empty
    assert(songs.len() == 0, 'Should return empty array');
}

#[test]
fn test_get_user_songs_single() {
    let dispatcher = deploy_contract();

    let user_felt: felt252 = 0x12345.into();
    let user: ContractAddress = user_felt.try_into().unwrap();
    // Set the caller to the test user
    start_cheat_caller_address(dispatcher.contract_address, user);

    // Register a song using the actual contract function
    let song_id = dispatcher
        .register_song('Test Song', 'ipfs_hash_1', 'preview_hash_1', 1000_u256, true);

    // Get songs for the user
    let songs = dispatcher.get_user_songs(user);

    // Check that the returned array contains the registered song
    assert(songs.len() == 1, 'Should have 1 song');
    assert(*songs.at(0) == song_id, 'Song ID mismatch');

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_get_user_songs_multiple() {
    let dispatcher = deploy_contract();
    let user_felt: felt252 = 0x12345.into();
    let user: ContractAddress = user_felt.try_into().unwrap();
    // Set the caller to the test user
    start_cheat_caller_address(dispatcher.contract_address, user);

    // Register multiple songs
    let song_id1 = dispatcher
        .register_song('Test Song 1', 'ipfs_hash_1', 'preview_hash_1', 1000_u256, true);

    let song_id2 = dispatcher
        .register_song('Test Song 2', 'ipfs_hash_2', 'preview_hash_2', 2000_u256, false);

    let song_id3 = dispatcher
        .register_song('Test Song 3', 'ipfs_hash_3', 'preview_hash_3', 3000_u256, true);

    // Get songs for the user
    let songs = dispatcher.get_user_songs(user);

    // Check that the returned array contains all registered songs
    assert(songs.len() == 3, 'Should have 3 songs');
    assert(*songs.at(0) == song_id1, 'Song ID 1 mismatch');
    assert(*songs.at(1) == song_id2, 'Song ID 2 mismatch');
    assert(*songs.at(2) == song_id3, 'Song ID 3 mismatch');

    stop_cheat_caller_address(dispatcher.contract_address);
}


#[test]
fn test_is_song_owner_true() {
    let dispatcher = deploy_contract();

    let user_felt: felt252 = 0x12345.into();
    let user: ContractAddress = user_felt.try_into().unwrap();

    start_cheat_caller_address(dispatcher.contract_address, user);

    let song_id = dispatcher
        .register_song('My Song', 'my_ipfs_hash', 'my_preview_hash', 1000_u256, false);

    // Check if the user is the owner of the song
    let is_owner = dispatcher.is_song_owner(user, song_id);

    assert(is_owner, 'User should be the owner');

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Non-owner should not be owner')]
fn test_is_song_owner_false() {
    let dispatcher = deploy_contract();

    // user addresses
    let owner_felt: felt252 = 0x12345.into();
    let owner: ContractAddress = owner_felt.try_into().unwrap();

    let non_owner_felt: felt252 = 0x12346.into();
    let non_owner: ContractAddress = non_owner_felt.try_into().unwrap();

    // set the caller to the owner
    start_cheat_caller_address(dispatcher.contract_address, owner);

    // register a song as the owner
    let song_id = dispatcher
        .register_song('Owner Song', 'owner_ipfs_hash', 'owner_preview_hash', 1000_u256, false);

    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, non_owner);

    // check if the non-owner is the owner of the song
    let is_owner = dispatcher.is_song_owner(non_owner, song_id);

    // the non-owner should not be the owner
    assert(is_owner, 'Non-owner should not be owner');
    stop_cheat_caller_address(dispatcher.contract_address);
}


#[test]
fn test_is_song_owner_invalid_id() {
    let dispatcher = deploy_contract();

    // user address
    let user_felt: felt252 = 0x12345.into();
    let user: ContractAddress = user_felt.try_into().unwrap();

    // check if the user is the owner of a song with an invalid ID
    let is_owner = dispatcher.is_song_owner(user, 9999);

    // should return false for invalid song ID
    assert(!is_owner, 'Should be false for invalid ID');
}

// CaxtonStone Stop