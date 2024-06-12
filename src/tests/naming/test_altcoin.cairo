use array::ArrayTrait;
use array::SpanTrait;
use option::OptionTrait;
use zeroable::Zeroable;
use traits::{Into, TryInto};
use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressZeroable;
use starknet::contract_address_const;
use starknet::testing::{set_contract_address, set_block_timestamp};
use identity::{
    identity::main::Identity, interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait}
};
use openzeppelin::token::erc20::{
    interface::{IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
};
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use naming::naming::utils::UtilsImpl;
use super::common::{deploy, deploy_stark};
use super::super::utils;
use wadray::Wad;

#[test]
#[available_gas(200000000000)]
fn test_convert_quote_to_eth() {
    let mut unsafe_state = Naming::unsafe_new_contract_state();

    // User wants to buy a domain in STRK for one year
    let domain_price_eth = Wad { val: 8999999999999875 };
    // 1 ETH = 1591.2053381608991 STRK
    let quote = Wad { val: 1591205338160899000000 };

    assert(
        UtilsImpl::get_altcoin_price(
            @unsafe_state, quote, domain_price_eth
        ) == 14320848043447892099_u256,
        'Wrong altcoin price'
    );
}

#[test]
#[available_gas(2000000000)]
fn test_buy_domain_with_strk() {
    // setup
    let (_eth, pricing, identity, naming) = deploy();
    let strk = deploy_stark();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    naming.set_server_pub_key(0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca);
    set_block_timestamp(500);

    //we mint the ids id
    identity.mint(id1);

    // we check how much a domain costs
    let quote = Wad { val: 1591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we allow the naming to take our money
    strk.approve(naming.contract_address, price_in_strk.into());

    // we buy with no resolver, no sponsor, no discount and empty metadata
    let max_validity = 1000;
    let sig = (
        0x6a15a81ccdb2deaa9038e92fd276584fcb7a5849ab959132c4c493f89559059,
        0x776e83e71aa21170dbacbd74d5e3c518acf073230fcca9900b3a5064da3d234
    );
    naming
        .altcoin_buy(
            id1,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            quote,
            max_validity,
            sig
        );

    assert(strk.allowance(caller, naming.contract_address) == 0, 'allowance not reset');
    assert(
        naming.domain_to_address(array![th0rgal].span(), array![].span()) == caller,
        'wrong domain target'
    );
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('quotation expired', 'ENTRYPOINT_FAILED'))]
fn test_buy_domain_altcoin_quote_expired() {
    // setup
    let (_eth, pricing, identity, naming) = deploy();
    let strk = deploy_stark();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    naming.set_server_pub_key(0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca);
    set_block_timestamp(500);

    //we mint the ids id
    identity.mint(id1);

    // we check how much a domain costs
    let quote = Wad { val: 1591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we allow the naming to take our money
    strk.approve(naming.contract_address, price_in_strk.into());

    // we buy with no resolver, no sponsor, no discount and empty metadata
    let max_validity = 1000;
    let sig = (
        0x6a15a81ccdb2deaa9038e92fd276584fcb7a5849ab959132c4c493f89559059,
        0x776e83e71aa21170dbacbd74d5e3c518acf073230fcca9900b3a5064da3d234
    );

    // we try buying after the max_validity timestamp
    set_block_timestamp(1500);
    naming
        .altcoin_buy(
            id1,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            quote,
            max_validity,
            sig
        );
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Invalid signature', 'ENTRYPOINT_FAILED'))]
fn test_buy_domain_altcoin_wrong_quote() {
    // setup
    let (_eth, pricing, identity, naming) = deploy();
    let strk = deploy_stark();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    naming.set_server_pub_key(0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca);
    set_block_timestamp(500);

    //we mint the ids id
    identity.mint(id1);

    // we check how much a domain costs
    let quote = Wad { val: 1591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we allow the naming to take our money
    strk.approve(naming.contract_address, price_in_strk.into());

    // we buy with no resolver, no sponsor, no discount and empty metadata
    let max_validity = 1000;
    let sig = (
        0x6a15a81ccdb2deaa9038e92fd276584fcb7a5849ab959132c4c493f89559059,
        0x776e83e71aa21170dbacbd74d5e3c518acf073230fcca9900b3a5064da3d234
    );
    // we try buying with a quote lower than the actual price
    let lower_quote = Wad { val: 1 };
    naming
        .altcoin_buy(
            id1,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            lower_quote,
            max_validity,
            sig
        );
}

#[test]
#[available_gas(2000000000)]
fn test_renew_domain_with_strk() {
    // setup
    let (_eth, pricing, identity, naming) = deploy();
    let strk = deploy_stark();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let th0rgal: felt252 = 33133781693;

    naming.set_server_pub_key(0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca);

    //we mint the ids id
    identity.mint(id1);

    // we check how much a domain costs
    let quote = Wad { val: 1591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we allow the naming to take our money
    strk.approve(naming.contract_address, price_in_strk.into());

    // we buy with no resolver, no sponsor, no discount and empty metadata
    let max_validity = 1000;
    let sig = (
        0x6a15a81ccdb2deaa9038e92fd276584fcb7a5849ab959132c4c493f89559059,
        0x776e83e71aa21170dbacbd74d5e3c518acf073230fcca9900b3a5064da3d234
    );
    naming
        .altcoin_buy(
            id1,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            quote,
            max_validity,
            sig
        );

    assert(strk.allowance(caller, naming.contract_address) == 0, 'allowance not reset');
    assert(
        naming.domain_to_address(array![th0rgal].span(), array![].span()) == caller,
        'wrong domain target'
    );

    // we check how much a domain costs to renew
    let quote = Wad { val: 591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we allow the naming to take our money
    strk.approve(naming.contract_address, price_in_strk.into());

    // we renew with no sponsor, no discount and empty metadata
    let max_validity = 1000;
    let sig = (
        0x1ac9f5e9a0239efa0efc9526db0cd650924b8b48b595cd9674a19eab84df962,
        0x1b78eabc5979b18e44ba4a2350de2597b9403b3777f54220fdf404c08933105
    );
    naming
        .altcoin_renew(
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            quote,
            max_validity,
            sig
        );
    assert(strk.allowance(caller, naming.contract_address) == 0, 'allowance not reset');
    assert(
        naming.domain_to_data(array![th0rgal].span()).expiry == 2 * 365 * 86400,
        'invalid renew expiry'
    );
}

#[test]
#[available_gas(200000000000)]
fn test_hash_matches() {
    let contract = contract_address_const::<
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
    >();
    let erc20_addr: felt252 = contract.into();

    let quote: Wad = Wad { val: 607843394028633 };
    let quote_felt: felt252 = quote.into();

    let max_validity: felt252 = 1709635880;

    let message_hash = core::hash::LegacyHash::hash(
        core::hash::LegacyHash::hash(
            core::hash::LegacyHash::hash(erc20_addr, quote_felt), max_validity
        ),
        'starknet id altcoin quote'
    );
    assert(
        message_hash == 0x00b693e8796152c46cbef85de6c8880520aad37af639702a70a3d907ff5cb114,
        'wrong hash'
    );
}

#[test]
#[available_gas(2000000000)]
fn test_subscription_with_strk() {
    // setup
    let (_eth, pricing, identity, naming) = deploy();
    let strk = deploy_stark();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let th0rgal: felt252 = 33133781693;
    naming.set_server_pub_key(0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca);

    //we mint the ids id
    identity.mint(id1);

    // we check how much a domain costs
    let quote = Wad { val: 1591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we allow the naming to take our money
    strk.approve(naming.contract_address, price_in_strk.into());

    // we buy with no resolver, no sponsor, no discount and empty metadata
    let max_validity = 1000;
    let sig = (
        0x6a15a81ccdb2deaa9038e92fd276584fcb7a5849ab959132c4c493f89559059,
        0x776e83e71aa21170dbacbd74d5e3c518acf073230fcca9900b3a5064da3d234
    );
    naming
        .altcoin_buy(
            id1,
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            quote,
            max_validity,
            sig
        );

    assert(strk.allowance(caller, naming.contract_address) == 0, 'allowance not reset');
    assert(
        naming.domain_to_address(array![th0rgal].span(), array![].span()) == caller,
        'wrong domain target'
    );

    // we check how much a domain costs to renew
    let quote = Wad { val: 591205338160899000000 };
    let (_, price_in_eth) = pricing.compute_buy_price(7, 365);
    let price_in_strk: Wad = Wad { val: price_in_eth.low } * quote;

    // we whitelist renewal contract
    let renewal_contract = contract_address_const::<0x456>();
    naming.whitelist_renewal_contract(renewal_contract);

    // to test, we transfer the price of the domain in STRK to the renewal contract
    // we allow the naming to take the price of the domain in STRK
    strk.transfer(renewal_contract, price_in_strk.into());
    set_contract_address(renewal_contract);
    strk.approve(naming.contract_address, price_in_strk.into());

    // we renew domain through renewal_contract
    naming
        .auto_renew_altcoin(
            th0rgal,
            365,
            ContractAddressZeroable::zero(),
            0,
            0,
            strk.contract_address,
            price_in_strk.into(),
        );
    assert(strk.allowance(caller, naming.contract_address) == 0, 'allowance not reset');
    assert(
        naming.domain_to_data(array![th0rgal].span()).expiry == 2 * 365 * 86400,
        'invalid renew expiry'
    );
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not whitelisted', 'ENTRYPOINT_FAILED'))]
fn test_subscription_not_whitelisted() {
    // setup
    let (_eth, _pricing, identity, naming) = deploy();
    let strk = deploy_stark();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    let id1: u128 = 1;
    let th0rgal: felt252 = 33133781693;
    naming.set_server_pub_key(0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca);

    //we mint the ids id
    identity.mint(id1);

    // we try to renew domain but we're not whitelisted
    naming
        .auto_renew_altcoin(
            th0rgal, 365, ContractAddressZeroable::zero(), 0, 0, strk.contract_address, 1.into()
        );
}
