use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address, test_address,
};
use starknet::{get_block_timestamp, get_caller_address, get_contract_address};
use super::*;
const SUBSCRIPTION_FEE: u256 = 20_000_000_000_000_000_000_000;

fn register_default_song() -> u64 {
    let (dispatcher, _) = deploy_contract();
    let song_id = dispatcher.register_song('name', 'hashin song', 'preview hash', 30);
    song_id
}
#[test]
fn test_subscription_payment() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };
    let subscribe_status_before = dispatcher.get_user(TEST_OWNER1());
    assert(!subscribe_status_before.has_subscribed, 'invalid status');

    let check_user_balance_before = erc20.balance_of(TEST_OWNER1());
    assert!(check_user_balance_before == 200_000_000_000_000_000_000_000, "An error occurred");

    let check_contract_balance_before = erc20.balance_of(dispatcher.contract_address);
    assert!(check_contract_balance_before == 0, "An error occurred");

    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000_000_000_000_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    start_cheat_block_timestamp(dispatcher.contract_address, get_block_timestamp() + 100);

    let update_time_stamp = dispatcher.update_subscription_details(TEST_OWNER1());
    assert!(update_time_stamp.subscription_id == 1, "An error occurred");
    assert!(update_time_stamp.start_date == get_block_timestamp() + 100, "An error occurred");

    let subscription = dispatcher.subscribe();
    assert!(subscription == 1, "subscription failed");

    let check_user_balance_after = erc20.balance_of(TEST_OWNER1());
    assert!(
        check_user_balance_after == 200_000_000_000_000_000_000_000 - SUBSCRIPTION_FEE,
        "An error occurred",
    );

    let check_contract_balance_after = erc20.balance_of(dispatcher.contract_address);
    assert!(check_contract_balance_after == SUBSCRIPTION_FEE, "An error occurred");

    stop_cheat_block_timestamp(dispatcher.contract_address);
    stop_cheat_caller_address(dispatcher.contract_address);

    let subscribe_status_after = dispatcher.get_user(TEST_OWNER1());
    assert(subscribe_status_after.has_subscribed, 'invalid status');
}

#[test]
#[should_panic(expect: "Invalid caller")]
fn test_subscription_payment_invalid_caller() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();
    let caller = contract_address_const::<0>();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };
    let subscribe_status_before = dispatcher.get_user(caller);
    assert(!subscribe_status_before.has_subscribed, 'invalid status');
    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, caller);
    erc20.approve(dispatcher.contract_address, 200_000_000_000_000_000_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, caller);
    start_cheat_block_timestamp(dispatcher.contract_address, get_block_timestamp() + 100);

    let update_time_stamp = dispatcher.update_subscription_details(caller);
    assert!(update_time_stamp.subscription_id == 1, "An error occurred");
    assert!(update_time_stamp.start_date == get_block_timestamp() + 100, "An error occurred");

    let subscription = dispatcher.subscribe();
    assert!(subscription == 1, "subscription failed");
    stop_cheat_block_timestamp(dispatcher.contract_address);
    stop_cheat_caller_address(dispatcher.contract_address);

    let subscribe_status_after = dispatcher.get_user(caller);
    assert(subscribe_status_after.has_subscribed, 'invalid status');
}

#[test]
#[should_panic(expect: "User has an active subscription")]
fn test_subscription_payment_has_active_subscription() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };
    let subscribe_status_before = dispatcher.get_user(TEST_OWNER1());
    assert(!subscribe_status_before.has_subscribed, 'invalid status');
    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000_000_000_000_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    start_cheat_block_timestamp(dispatcher.contract_address, get_block_timestamp() + 100);

    dispatcher.update_user(TEST_OWNER1());

    let update_time_stamp = dispatcher.update_subscription_details(TEST_OWNER1());
    assert!(update_time_stamp.subscription_id == 1, "An error occurred");
    assert!(update_time_stamp.start_date == get_block_timestamp() + 100, "An error occurred");

    let subscription = dispatcher.subscribe();
    dispatcher.subscribe();

    assert!(subscription == 1, "subscription failed");
    stop_cheat_block_timestamp(dispatcher.contract_address);
    stop_cheat_caller_address(dispatcher.contract_address);

    let subscribe_status_after = dispatcher.get_user(TEST_OWNER1());
    assert(subscribe_status_after.has_subscribed, 'invalid status');
}

#[test]
#[should_panic(expect: "Subscription has expired")]
fn test_subscription_payment_expired_subscription() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };
    let subscribe_status_before = dispatcher.get_user(TEST_OWNER1());
    assert(!subscribe_status_before.has_subscribed, 'invalid status');
    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000_000_000_000_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    start_cheat_block_timestamp(dispatcher.contract_address, get_block_timestamp() + 100);

    dispatcher.update_user(TEST_OWNER1());

    let subscription = dispatcher.subscribe();
    dispatcher.subscribe();

    assert!(subscription == 1, "subscription failed");
    stop_cheat_block_timestamp(dispatcher.contract_address);
    stop_cheat_caller_address(dispatcher.contract_address);

    let subscribe_status_after = dispatcher.get_user(TEST_OWNER1());
    assert(subscribe_status_after.has_subscribed, 'invalid status');
}

#[test]
#[should_panic(expect: 'Insufficient allowance')]
fn test_subscription_failed_stark_payment() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };
    let subscribe_status_before = dispatcher.get_user(TEST_OWNER1());
    assert(!subscribe_status_before.has_subscribed, 'invalid status');
    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    start_cheat_block_timestamp(dispatcher.contract_address, get_block_timestamp() + 100);

    dispatcher.update_user(TEST_OWNER1());

    let update_time_stamp = dispatcher.update_subscription_details(TEST_OWNER1());
    assert!(update_time_stamp.subscription_id == 1, "An error occurred");
    assert!(update_time_stamp.start_date == get_block_timestamp() + 100, "An error occurred");

    let subscription = dispatcher.subscribe();
    dispatcher.subscribe();

    assert!(subscription == 1, "subscription failed");
    stop_cheat_block_timestamp(dispatcher.contract_address);
    stop_cheat_caller_address(dispatcher.contract_address);

    let subscribe_status_after = dispatcher.get_user(TEST_OWNER1());
    assert(subscribe_status_after.has_subscribed, 'invalid status');
}

#[test]
fn test_buy_song_payment() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER2());
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 30);
    dispatcher.set_song_for_sale(song_id);
    stop_cheat_caller_address(dispatcher.contract_address);

    let check_owner_before_buy = dispatcher.get_song_info(song_id).owner;
    assert!(check_owner_before_buy == TEST_OWNER2(), "An error occurred fetching song owner");

    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    let buyer_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(buyer_balance1 == 200_000_000_000_000_000_000_000, "incorrect balance");

    let seller_balance1 = erc20.balance_of(TEST_OWNER2());
    assert!(seller_balance1 == 0, "incorrect balance of seller");

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let buy_song = dispatcher.buy_song(song_id);
    assert!(buy_song == 'i dont know', "Could not buy song");

    stop_cheat_caller_address(dispatcher.contract_address);

    let buyer_balance2 = erc20.balance_of(TEST_OWNER1());
    assert!(buyer_balance2 == 200_000_000_000_000_000_000_000 - 30, "incorrect balance");

    let seller_balance1 = erc20.balance_of(TEST_OWNER2());
    assert!(seller_balance1 == 30, "incorrect balance of seller");

    let check_owner_after_buy = dispatcher.get_song_info(song_id);
    assert!(check_owner_after_buy.owner == TEST_OWNER1(), "An error occurred changing song owner");
}

#[test]
#[should_panic(expect: "You cannot buy your own song")]
fn test_buy_song_payment_own_song() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 30);
    stop_cheat_caller_address(dispatcher.contract_address);

    let check_owner_before_buy = dispatcher.get_song_info(song_id).owner;
    assert!(check_owner_before_buy == TEST_OWNER1(), "An error occurred fetching song owner");

    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    let buyer_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(buyer_balance1 == 200_000_000_000_000_000_000_000, "incorrect balance");

    let seller_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(seller_balance1 == 0, "incorrect balance of seller");

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let buy_song = dispatcher.buy_song(song_id);
    assert!(buy_song == 'i dont know', "Could not buy song");

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: "Song is not for sale")]
fn test_buy_song_not_for_sale() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 30);
    stop_cheat_caller_address(dispatcher.contract_address);

    let check_owner_before_buy = dispatcher.get_song_info(song_id).owner;
    assert!(check_owner_before_buy == TEST_OWNER1(), "An error occurred fetching song owner");

    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 200_000_000);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    let buyer_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(buyer_balance1 == 200_000_000_000_000_000_000_000, "incorrect balance");

    let seller_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(seller_balance1 == 0, "incorrect balance of seller");

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let buy_song = dispatcher.buy_song(song_id);
    assert!(buy_song == 'i dont know', "Could not buy song");

    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expect: 'Insufficient allowance')]
fn test_buy_song_insufficient_allowance() {
    let (dispatcher, erc_20_dispatcher) = deploy_contract();

    let erc20: IERC20Dispatcher = IERC20Dispatcher {
        contract_address: erc_20_dispatcher.contract_address,
    };

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let song_id = dispatcher.register_song('why me', 'i dont know', 'cohort 4', 30);
    stop_cheat_caller_address(dispatcher.contract_address);

    let check_owner_before_buy = dispatcher.get_song_info(song_id).owner;
    assert!(check_owner_before_buy == TEST_OWNER1(), "An error occurred fetching song owner");

    // Approve the DISPATCHER contract to spend tokens
    start_cheat_caller_address(erc_20_dispatcher.contract_address, TEST_OWNER1());
    erc20.approve(dispatcher.contract_address, 2);
    stop_cheat_caller_address(erc_20_dispatcher.contract_address);

    let buyer_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(buyer_balance1 == 200_000_000_000_000_000_000_000, "incorrect balance");

    let seller_balance1 = erc20.balance_of(TEST_OWNER1());
    assert!(seller_balance1 == 0, "incorrect balance of seller");

    start_cheat_caller_address(dispatcher.contract_address, TEST_OWNER1());
    let buy_song = dispatcher.buy_song(song_id);
    assert!(buy_song == 'i dont know', "Could not buy song");

    stop_cheat_caller_address(dispatcher.contract_address);
}
