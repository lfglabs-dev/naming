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
fn test_buy_price() {
    let pricing = deploy_pricing();

    // Test with "b" / 1 letter and one year
    let (erc20, price) = pricing.compute_buy_price(1, 365);
    assert(erc20.into() == 0x123, 'wrong erc20 address');
    assert(price == 390000000000000180, 'incorrect price');

    // Test with "be" / 2 letters and one year
    let (erc20, price) = pricing.compute_buy_price(153, 365);
    assert(price == 240000000000000195, 'incorrect price');

    // Test with "ben" / 3 letters and one year
    let (erc20, price) = pricing.compute_buy_price(18925, 365);
    assert(price == 73000000000000000, 'incorrect price');

    // Test with "benj" / 4 letters and one year
    let (erc20, price) = pricing.compute_buy_price(512773, 365);
    assert(price == 26999999999999990, 'incorrect price');

    // Test with "chocolate" / 9 letters and one year
    let (erc20, price) = pricing.compute_buy_price(19565965532212, 365);
    assert(price == 24657534246575 * 365, 'incorrect price');

    // Test with "chocolate" / 9 letters and 5 years
    let (erc20, price) = pricing.compute_buy_price(19565965532212, 1825);
    assert(price == 24657534246575 * 1825, 'incorrect price');

    // Test with "chocolate" / 9 letters and 3 years
    let (erc20, price) = pricing.compute_buy_price(19565965532212, 1095);
    assert(price == 24657534246575 * 1095, 'incorrect price');

    // Test with "chocolate" / 9 letters and 20 years
    let (erc20, price) = pricing.compute_buy_price(19565965532212, 7300);
    assert(price == 24657534246575 * 7300, 'incorrect price');
}


#[cfg(test)]
#[test]
#[available_gas(200000000000)]
fn test_get_amount_of_chars() {
    let mut unsafe_state = Pricing::unsafe_new_contract_state();

    // Should return 0 (empty string)
    assert(Pricing::InternalImpl::get_amount_of_chars(@unsafe_state, 0) == 0, 'Should return 0');

    // Should return 2 (be)
    assert(Pricing::InternalImpl::get_amount_of_chars(@unsafe_state, 153) == 2, 'Should return 0');

    // Should return 4 ("toto")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(@unsafe_state, 796195) == 4, 'Should return 4'
    );

    // Should return 5 ("aloha")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(@unsafe_state, 77554770) == 5, 'Should return 5'
    );

    // Should return 9 ("chocolate")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(@unsafe_state, 19565965532212) == 9,
        'Should return 9'
    );

    // Should return 30 ("这来abcdefghijklmopqrstuvwyq1234")
    assert(
        Pricing::InternalImpl::get_amount_of_chars(
            @unsafe_state, 801855144733576077820330221438165587969903898313
        ) == 30,
        'Should return 30'
    );
}
