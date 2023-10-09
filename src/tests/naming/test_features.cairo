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
use openzeppelin::token::erc20::{
    erc20::ERC20, interface::{IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
};
use identity::{
    identity::main::Identity, interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait}
};
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use naming::naming::utils::UtilsImpl;
use super::common::deploy;
use super::super::utils;


#[test]
#[available_gas(2000000000)]
fn test_subdomains() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let id2: u128 = 2;
    let th0rgal: felt252 = 33133781693;
    let hello: felt252 = 29811539;

    //we mint the ids id
    identity.mint(id1);
    identity.mint(id2);

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(7, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(
            id1,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0
        );

    let subdomain = array![hello, th0rgal].span();

    // we transfer hello.th0rgal.stark to id2
    naming.transfer_domain(subdomain, id2);

    assert(naming.domain_to_address(subdomain) == caller, 'wrong subdomain initial target');

    // and make sure the owner has been updated
    assert(naming.domain_to_id(subdomain) == id2, 'owner not updated correctly');

    let root_domain = array![th0rgal].span();

    // we reset subdomains
    naming.reset_subdomains(root_domain);

    // ensure th0rgal still resolves
    assert(naming.domain_to_id(root_domain) == id1, 'owner not updated correctly');

    // ensure the subdomain was reset
    assert(
        naming.domain_to_address(subdomain) == ContractAddressZeroable::zero(),
        'target not updated correctly'
    );
}

#[test]
#[available_gas(2000000000)]
fn test_claim_balance() {
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

    let contract_bal = eth.balanceOf(naming.contract_address);
    let admin_balance = eth.balanceOf(caller);
    assert(contract_bal == price, 'naming has wrong balance');
    naming.claim_balance(eth.contract_address);
    assert(admin_balance + price == eth.balanceOf(caller), 'balance didn\'t increase');
}


#[test]
#[available_gas(200000000000)]
fn test_get_chars_len() {
    let mut unsafe_state = Naming::unsafe_new_contract_state();

    // Should return 0 (empty string)
    assert(UtilsImpl::get_chars_len(@unsafe_state, 0) == 0, 'Should return 0');

    // Should return 2 (be)
    assert(UtilsImpl::get_chars_len(@unsafe_state, 153) == 2, 'Should return 0');

    // Should return 4 ("toto")
    assert(UtilsImpl::get_chars_len(@unsafe_state, 796195) == 4, 'Should return 4');

    // Should return 5 ("aloha")
    assert(UtilsImpl::get_chars_len(@unsafe_state, 77554770) == 5, 'Should return 5');

    // Should return 9 ("chocolate")
    assert(UtilsImpl::get_chars_len(@unsafe_state, 19565965532212) == 9, 'Should return 9');

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    assert(
        UtilsImpl::get_chars_len(
            @unsafe_state, 801855144733576077820330221438165587969903898313
        ) == 30,
        'Should return 30'
    );
}
