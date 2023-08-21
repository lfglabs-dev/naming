use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;
use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressZeroable;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use super::utils;
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use identity::interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait};
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use super::identity::Identity;
use super::erc20::ERC20;

#[cfg(test)]
fn deploy() -> (IERC20Dispatcher, IPricingDispatcher, IIdentityDispatcher, INamingDispatcher) {
    //erc20
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append('ether');
    calldata.append('ETH');
    calldata.append(0); // low
    calldata.append(1); // high (2^128)
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
    (
        IERC20Dispatcher {
            contract_address: eth
            }, IPricingDispatcher {
            contract_address: pricing
            }, IIdentityDispatcher {
            contract_address: identity
            }, INamingDispatcher {
            contract_address: address
        }
    )
}

#[cfg(test)]
#[test]
#[available_gas(2000000000)]
fn test_basic_usage() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    //we mint an id
    identity.mint(id);

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(th0rgal, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor and empty metadata
    naming
        .buy(id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0);

    // let's try the resolving
    let domain = array![th0rgal].span();
    // by default we should have nothing written
    assert(naming.resolve(domain, 'starknet') == 0, 'non empty starknet field');
    // so it should resolve to the starknetid owner
    assert(naming.domain_to_address(domain) == caller, 'wrong domain target');
}
