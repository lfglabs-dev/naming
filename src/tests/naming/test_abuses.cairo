use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use zeroable::Zeroable;
use traits::Into;
use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressZeroable;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use super::super::utils;
use openzeppelin::token::erc20::{
    interface::{IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
};
use identity::{
    identity::main::Identity, interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait}
};
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use super::common::{deploy, deploy_with_erc20_fail};

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('ERC20: insufficient balance', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_not_enough_eth() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    // 0x789 doesn't have eth
    let caller = contract_address_const::<0x789>();
    set_contract_address(caller);
    let id: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    //we mint an id
    identity.mint(id);

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(7, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata (and also no money)
    naming
        .buy(
            id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0
        );
}


#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('unexpired domain', 'ENTRYPOINT_FAILED'))]
fn test_buying_domain_twice() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let id2: u128 = 2;
    let th0rgal: felt252 = 33133781693;

    //we mint the ids
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

    // buying again
    naming
        .buy(
            id2,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0
        );
}


#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('this id holds a domain', 'ENTRYPOINT_FAILED'))]
fn test_buying_twice_on_same_id() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id: u128 = 1;
    let th0rgal: felt252 = 33133781693;
    let altdomain: felt252 = 57437602667574;

    //we mint an id
    identity.mint(id);

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(7, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, 2 * price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(
            id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0
        );
    naming
        .buy(
            id,
            altdomain,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0
        );
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('you don\'t own this domain', 'ENTRYPOINT_FAILED'))]
fn test_non_owner_cannot_transfer_domain() {
    // setup
    let (_, _, identity, naming) = deploy();

    let caller_owner = contract_address_const::<0x123>();
    let caller_not_owner = contract_address_const::<0x456>();

    set_contract_address(caller_owner);

    let id_owner = 1;
    let id_not_owner = 2;
    let domain_name = array![33133781693].span(); // th0rgal

    // Mint IDs for both users.
    identity.mint(id_owner);

    // Assuming you've already acquired the domain for id_owner.
    // Transfer domain using a non-owner ID should panic.
    set_contract_address(caller_not_owner);
    identity.mint(id_not_owner);
    naming.transfer_domain(domain_name, id_not_owner);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('min purchase of 6 months', 'ENTRYPOINT_FAILED'))]
fn test_renewal_period_too_short() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    // Mint an ID and simulate the process of buying a domain
    identity.mint(id);
    let (_, price) = pricing.compute_buy_price(7, 365);
    eth.approve(naming.contract_address, price);
    naming
        .buy(
            id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0
        );

    // Try to renew the domain for a period shorter than the allowed minimum
    let (_, price) = pricing.compute_renew_price(7, 5 * 30);
    eth.approve(naming.contract_address, price);
    naming.renew(th0rgal, 5 * 30, ContractAddressZeroable::zero(), 0, 0);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('max purchase of 25 years', 'ENTRYPOINT_FAILED'))]
fn test_renewal_period_too_long() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    // Mint an ID and simulate the process of buying a domain
    identity.mint(id);
    let (_, price) = pricing.compute_buy_price(7, 365);
    eth.approve(naming.contract_address, price);
    naming
        .buy(
            id, th0rgal, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0
        );

    // Try to renew for a period that, when added to the domain's current expiry, exceeds the allowed limit.
    let (_, price) = pricing.compute_renew_price(7, 9130);
    eth.approve(naming.contract_address, price);
    naming.renew(th0rgal, 9130, ContractAddressZeroable::zero(), 0, 0);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_non_admin_cannot_claim_balance() {
    // setup
    let (eth, _, _, naming) = deploy();
    let non_admin_address = contract_address_const::<0x456>();
    set_contract_address(non_admin_address);

    // A non-admin tries to claim the balance of the contract
    naming.claim_balance(eth.contract_address);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('a parent domain was reset', 'ENTRYPOINT_FAILED'))]
fn test_use_reset_subdomains() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let alpha = contract_address_const::<0x123>();
    let bravo = contract_address_const::<0x456>();

    // we mint the ids

    set_contract_address(alpha);
    identity.mint(1);
    set_contract_address(bravo);
    identity.mint(2);

    set_contract_address(alpha);
    let aller: felt252 = 35683102;

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(5, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(1, aller, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0);

    let root_domain = array![aller].span();
    let subdomain = array![aller, aller].span();

    // we transfer aller.aller.stark to id2
    naming.transfer_domain(subdomain, 2);

    // and make sure the owner has been updated
    assert(naming.domain_to_id(subdomain) == 2, 'owner not updated correctly');

    // now bravo should be able to create a subsubdomain (charlie.aller.aller.stark):
    set_contract_address(bravo);
    let subsubdomain = array!['charlie', aller, aller].span();
    naming.transfer_domain(subsubdomain, 3);

    // alpha resets subdomains of aller.stark
    set_contract_address(alpha);
    naming.reset_subdomains(root_domain);

    // ensure aller.stark still resolves
    assert(naming.domain_to_id(root_domain) == 1, 'owner not updated correctly');
    // ensure the subdomain was reset
    assert(naming.domain_to_id(subdomain) == 0, 'owner not updated correctly');

    set_contract_address(bravo);
    let subsubdomain2 = array!['delta', aller, aller].span();
    naming.transfer_domain(subsubdomain2, 4);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('payment failed', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_returns_false() {
    // setup
    let (eth, pricing, identity, naming) = deploy_with_erc20_fail();
    let alpha = contract_address_const::<0x123>();

    // we mint the id
    set_contract_address(alpha);
    identity.mint(1);

    set_contract_address(alpha);
    let aller: felt252 = 35683102;

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(5, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    // in pay_domain transferFrom will return false
    naming
        .buy(1, aller, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0);
}

#[test]
#[available_gas(2000000000)]
fn test_use_reset_subdomains_multiple_levels() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let alpha = contract_address_const::<0x123>();
    let bravo = contract_address_const::<0x456>();
    let charlie = contract_address_const::<0x789>();
    // In this example we will use utf-8 encoded strings like 'toto' which is not 
    // what is actually defined in the starknetid standard, it's just easier for testings

    // we mint the ids
    set_contract_address(alpha);
    identity.mint(1);
    set_contract_address(bravo);
    identity.mint(2);
    set_contract_address(charlie);
    identity.mint(3);

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(5, 365);

    // we allow the naming to take our money
    set_contract_address(alpha);
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(
            1, 'ccccc', 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0
        );

    let root_domain = array!['ccccc'].span();
    let subdomain = array!['bbbbb', 'ccccc'].span();

    // we transfer bb.cc.stark to id2
    naming.transfer_domain(subdomain, 2);

    // and make sure the owner has been updated
    assert(naming.domain_to_id(subdomain) == 2, 'owner not updated correctly');

    set_contract_address(bravo);
    // we transfer aa.bb.cc.stark to id3
    let subsubdomain = array!['aaaaa', 'bbbbb', 'ccccc'].span();
    naming.transfer_domain(subsubdomain, 3);
    // and make sure the owner has been updated
    assert(naming.domain_to_id(subsubdomain) == 3, 'owner2 not updated correctly');

    // now charlie should be able to create a subbsubsubdomain (example.aa.bb.cc.stark):
    set_contract_address(charlie);
    let subsubsubdomain = array!['example', 'aaaaa', 'bbbbb', 'ccccc'].span();
    naming.transfer_domain(subsubsubdomain, 4);

    // alpha resets subdomains of ccccc.stark
    set_contract_address(alpha);
    naming.reset_subdomains(root_domain);

    // ensure root domain still resolves
    assert(naming.domain_to_id(root_domain) == 1, 'owner3 not updated correctly');
    // ensure the subdomain was reset
    assert(naming.domain_to_id(subdomain) == 0, 'owner4 not updated correctly');
    // ensure the subsubdomain was reset
    assert(naming.domain_to_id(subsubdomain) == 0, 'owner5 not updated correctly');
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('domain can\'t be empty', 'ENTRYPOINT_FAILED'))]
fn test_buy_empty_domain() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let alpha = contract_address_const::<0x123>();

    // we mint the id
    set_contract_address(alpha);
    identity.mint(1);

    set_contract_address(alpha);
    let empty_domain: felt252 = 0;

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(0, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(
            1,
            empty_domain,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0
        );
}


#[test]
#[available_gas(2000000000)]
fn test_subdomain_reverse() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let alpha = contract_address_const::<0x123>();
    let bravo = contract_address_const::<0x456>();
    let charlie = contract_address_const::<0x789>();

    // we mint the ids
    set_contract_address(alpha);
    identity.mint(1);
    set_contract_address(bravo);
    identity.mint(2);
    set_contract_address(charlie);
    identity.mint(3);

    set_contract_address(alpha);
    let aller: felt252 = 35683102;

    // we check how much a domain costs
    let (_, price) = pricing.compute_buy_price(5, 365);

    // we allow the naming to take our money
    eth.approve(naming.contract_address, price);

    // we buy with no resolver, no sponsor, no discount and empty metadata
    naming
        .buy(1, aller, 365, ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0, 0);

    let subdomain = array![aller, aller].span();

    // we transfer aller.aller.stark to id2
    naming.transfer_domain(subdomain, 2);

    // and make sure the owner has been updated
    assert(naming.domain_to_id(subdomain) == 2, 'owner not updated correctly');
    set_contract_address(bravo);
    let result = naming.address_to_domain(bravo, array![].span());
    assert(result == array![].span(), 'unexpected result');
    // we then set this subdomain as main domain and ensures reverse resolving works
    identity.set_main_id(2);
    let result = naming.address_to_domain(bravo, array![].span());
    assert(result == subdomain, 'unexpected result');
    // before transfering this subdomain
    naming.transfer_domain(subdomain, 3);
    let result = naming.address_to_domain(bravo, array![].span());
    assert(result == array![].span(), 'unexpected result');
}
