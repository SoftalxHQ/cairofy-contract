pub mod test_cairofy;
use cairofy_contract::contracts::Cairofy::CairofyV0;
use cairofy_contract::events::Events::{SongPriceUpdated, Song_Registered};
use cairofy_contract::interfaces::ICairofy::{ICairofyDispatcher, ICairofyDispatcherTrait};
use openzeppelin::token::erc20::interface::{
    ERC20ABIDispatcher, ERC20ABIDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait,
    IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address, test_address,
};
use starknet::{ContractAddress, contract_address_const};
use super::*;

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

fn deploy_contract() -> (ICairofyDispatcher, IERC20Dispatcher) {
    // Deploy mock ERC20
    let erc20_class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![TEST_OWNER1().into(), OWNER().into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();
    let erc_20_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // Deploy Cairofy contract
    let contract_class = declare("CairofyV0").unwrap().contract_class();
    let (cairofy_address, _) = contract_class
        .deploy(@array![OWNER().into(), erc20_address.into()])
        .unwrap();

    let dispatcher = ICairofyDispatcher { contract_address: cairofy_address };

    (dispatcher, erc_20_dispatcher)
}
