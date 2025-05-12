use super::*;


fn register_default_song() -> u64 {
    let (dispatcher, _) = deploy_contract();
    let song_id = dispatcher.register_song('name', 'hashin song', 'preview hash', 30, true);
    song_id
}
#[test]
fn test_register_song() {
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
    dispatcher.register_song('', 'i dont know', 'cohort 4', 20, true);
}
#[test]
#[should_panic(expect: "Your song hash cannot be empty")]
fn test_register_empty_song_hash() {
    let (dispatcher, _) = deploy_contract();
    dispatcher.register_song('why me', '', 'cohort 4', 20, true);
}
#[test]
#[should_panic(expect: "Your song preview hash cannot be empty")]
fn test_register_empty_preview_song_hash() {
    let (dispatcher, _) = deploy_contract();
    dispatcher.register_song('why me', 'i dont know', '', 20, true);
}
#[test]
#[should_panic(expect: "Price must be greater than 0")]
fn test_register_song_zero_price() {
    let (dispatcher, _) = deploy_contract();
    dispatcher.register_song('why me', 'i dont know', 'cohort 4', 0, true);
}

#[test]
fn test_update_song_price() {
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(10, 500);
}

#[test]
#[should_panic(expect: "Price must be greater than 0")]
fn test_update_song_price_invalid_price() {
    let (dispatcher, _) = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());

    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 0);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_update_song_price_owner() {
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());

    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 20, true);

    dispatcher.update_song_price(song_id, 0);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_update_song_price_event() {
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
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
    let (dispatcher, _) = deploy_contract();
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
