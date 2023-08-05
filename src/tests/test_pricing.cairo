use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;

use starknet::ContractAddress;
use starknet::testing;
use super::utils;
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::pricing::Pricing;

#[cfg(test)]
fn deploy_pricing() -> IPricingDispatcher {
    let mut calldata = ArrayTrait::<felt252>::new();
    // erc20 address
    calldata.append(0x123);
    let address = utils::deploy(Pricing::TEST_CLASS_HASH, calldata);
    IPricingDispatcher { contract_address: address }
}


#[cfg(test)]
#[test]
#[available_gas(20000000000)]
fn test_erc20() {
    let pricing = deploy_pricing();

    // buying th0rgal.stark for 365 days
    let (erc20, price) = pricing.compute_buy_price(33133781693, 365);
    assert(erc20.into() == 0x123, 'wrong erc20 address');
}

#[cfg(test)]
#[test]
#[available_gas(20000000000)]
fn test_get_amount_of_chars() {
    let mut unsafe_state = Pricing::unsafe_new_contract_state();

    // Should return 0 (empty string)
    assert(
        Pricing::InternalImpl::get_amount_of_chars(@unsafe_state, u256 { low: 0, high: 0 }) == 0,
        'Should return 0'
    );

    // Should return 4 ("toto")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(
            @unsafe_state, u256 { low: 796195, high: 0 }
        ) == 4,
        'Should return 4'
    );

    // Should return 5 ("aloha")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(
            @unsafe_state, u256 { low: 77554770, high: 0 }
        ) == 5,
        'Should return 5'
    );

    // Should return 9 ("chocolate")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(
            @unsafe_state, u256 { low: 19565965532212, high: 0 }
        ) == 9,
        'Should return 9'
    );

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(
            @unsafe_state,
            integer::u256_from_felt252(801855144733576077820330221438165587969903898313)
        ) == 30,
        'Should return 30'
    );
}
