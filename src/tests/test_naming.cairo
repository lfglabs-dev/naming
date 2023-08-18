use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;
use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressZeroable;
use starknet::contract_address_const;
use starknet::testing::set_caller_address;
use super::utils;
use identity::identity::main::Identity;
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use super::erc20::ERC20;

#[cfg(test)]
fn deploy() -> INamingDispatcher {
    //erc20
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append('ether');
    calldata.append('ETH');
    calldata.append(0);
    calldata.append(1024);
    calldata.append(0x123);
    let eth = utils::deploy(ERC20::TEST_CLASS_HASH, calldata);

    // pricing
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(eth.into());
    let pricing = utils::deploy(Pricing::TEST_CLASS_HASH, calldata);

    // identity
    let identity = utils::deploy(Identity::TEST_CLASS_HASH, ArrayTrait::<felt252>::new());

    // naming
    let mut calldata = ArrayTrait::<felt252>::new();
    let admin = 0x123;
    calldata.append(identity.into());
    calldata.append(pricing.into());
    calldata.append(0);
    calldata.append(admin);
    let address = utils::deploy(Naming::TEST_CLASS_HASH, calldata);
    INamingDispatcher { contract_address: address }
}

#[cfg(test)]
#[test]
#[available_gas(20000000000)]
fn test_deploying() {
    let naming = deploy();
    let caller = contract_address_const::<0x123>();
    set_caller_address(caller);

    let th0rgal = 33133781693;
    //naming.buy(1, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero());
}

