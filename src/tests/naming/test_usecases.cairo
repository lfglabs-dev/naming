use array::ArrayTrait;
use array::SpanTrait;
use debug::PrintTrait;
use option::OptionTrait;
use zeroable::Zeroable;
use traits::Into;
use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressZeroable;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use super::super::utils;
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use identity::interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait};
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use super::super::identity::Identity;
use super::super::erc20::ERC20;
use super::common::deploy;
use naming::naming::main::Naming::Discount;

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
    let (_, price) = pricing.compute_buy_price(7, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(
            id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0
        );

    // let's try the resolving
    let domain = array![th0rgal].span();
    // by default we should have nothing written
    assert(naming.resolve(domain, 'starknet') == 0, 'non empty starknet field');
    // so it should resolve to the starknetid owner
    assert(naming.domain_to_address(domain) == caller, 'wrong domain target');

    // let's try reverse resolving
    identity.set_main_id(id);
    assert(domain.len() == 1, 'invalid domain length');
    assert(domain.at(0) == @th0rgal, 'wrong domain');

    // now let's change the target
    let new_target = contract_address_const::<0x456>();
    identity.set_user_data(id, 'starknet', new_target.into(), 0);

    // now we should have nothing written
    assert(naming.resolve(domain, 'starknet') == new_target.into(), 'wrong starknet field');
    // and it should resolve to the new domain target
    assert(naming.domain_to_address(domain) == new_target, 'wrong domain target');

    // testing ownership transfer
    let new_id = 2;
    naming.transfer_domain(domain, new_id);
    assert(naming.domain_to_id(domain) == new_id, 'owner not updated correctly');
}


#[cfg(test)]
#[test]
#[available_gas(2000000000)]
fn test_discounts() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);

    // you pay only 50%
    naming.set_discount('half', Discount{
        domain_len_range: (1, 50),
        days_range: (365, 365),
        timestamp_range: (0, 0xffffffffffffffff),
        amount: 50,
    });

    let id: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    //we mint an id
    identity.mint(id);

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(7, 365);
    let to_pay = price/2;

    // we allow the naming to take our money
    eth.approve(naming.contract_address, to_pay);

    // we buy with no resolver, no sponsor, empty metadata but our HALF discount
    naming
        .buy(
            id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 'half', 0
        );
}
