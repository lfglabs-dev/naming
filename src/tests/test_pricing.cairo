use array::ArrayTrait;
use zeroable::Zeroable;
use traits::Into;

use starknet::ContractAddress;
use starknet::testing;
use super::utils;
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::pricing::Pricing;

fn deploy_pricing() -> IPricingDispatcher {
    let mut calldata = ArrayTrait::<felt252>::new();
    // erc20 address
    calldata.append(0x123);
    let address = utils::deploy(Pricing::TEST_CLASS_HASH, calldata);
    IPricingDispatcher { contract_address: address }
}

#[test]
#[available_gas(20000000000)]
fn test_buy_price() {
    let pricing = deploy_pricing();

    // Test with "b" / 1 letter and one year
    let (erc20, price) = pricing.compute_buy_price(1, 365);
    assert(erc20.into() == 0x123, 'wrong erc20 address');
    assert(price == 99999999999999990, 'incorrect price');

    // Test with "be" / 2 letters and one year
    let (_erc20, price) = pricing.compute_buy_price(2, 365);
    assert(price == 49999999999999995, 'incorrect price');

    // Test with "ben" / 3 letters and one year
    let (_erc20, price) = pricing.compute_buy_price(3, 365);
    assert(price == 24999999999999815, 'incorrect price');

    // Test with "benj" / 4 letters and one year
    let (_erc20, price) = pricing.compute_buy_price(4, 365);
    assert(price == 13499999999999995, 'incorrect price');

    // Test with "chocolate" / 9 letters and one year
    let (_erc20, price) = pricing.compute_buy_price(9, 365);
    assert(price == 24657534246575 * 365, 'incorrect price');

    // Test with "chocolate" / 9 letters and 5 years
    let (_erc20, price) = pricing.compute_buy_price(9, 1825);
    assert(price == 24657534246575 * 1825, 'incorrect price');

    // Test with "chocolate" / 9 letters and 3 years
    let (_erc20, price) = pricing.compute_buy_price(9, 1095);
    assert(price == 24657534246575 * 1095, 'incorrect price');

    // Test with "chocolate" / 9 letters and 20 years
    let (_erc20, price) = pricing.compute_buy_price(9, 7300);
    assert(price == 24657534246575 * 7300, 'incorrect price');
}
