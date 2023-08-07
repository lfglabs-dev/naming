use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;

use starknet::ContractAddress;
use starknet::testing;
use super::utils;
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;

#[cfg(test)]
fn deploy() -> INamingDispatcher {

    //erc20
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(0x789);
    let pricing = utils::deploy(Pricing::TEST_CLASS_HASH, calldata);

    // pricing
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(0x789);
    let pricing = utils::deploy(Pricing::TEST_CLASS_HASH, calldata);

    // naming
    let mut calldata = ArrayTrait::<felt252>::new();
    let starknetid = 0x456;
    let admin = 0x123;
    calldata.append(starknetid);
    calldata.append(pricing.into());
    calldata.append(admin);
    let address = utils::deploy(Naming::TEST_CLASS_HASH, calldata);
    INamingDispatcher { contract_address: address }
}

#[cfg(test)]
#[test]
#[available_gas(20000000000)]
fn test_buy_price() {
    deploy();
}

