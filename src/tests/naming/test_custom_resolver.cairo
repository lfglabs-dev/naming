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
use super::common::deploy;
use naming::naming::main::Naming::Discount;
use naming::interface::resolver::IResolver;

#[starknet::contract]
mod CustomResolver {
    use core::array::SpanTrait;
    use naming::interface::resolver::IResolver;
    use debug::PrintTrait;

    #[storage]
    struct Storage {}


    #[external(v0)]
    impl AdditionResolveImpl of IResolver<ContractState> {
        fn resolve(
            self: @ContractState, mut domain: Span<felt252>, field: felt252, hint: Span<felt252>
        ) -> felt252 {
            let mut output = 0;
            loop {
                match domain.pop_front() {
                    Option::Some(domain_part) => { output += *domain_part; },
                    Option::None => { break; }
                }
            };
            output
        }
    }
}


#[test]
#[available_gas(2000000000)]
fn test_custom_resolver() {
    // setup
    let (eth, pricing, identity, naming) = deploy();
    let custom_resolver = IERC20CamelDispatcher {
        contract_address: utils::deploy(CustomResolver::TEST_CLASS_HASH, ArrayTrait::new())
    };

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
            id,
            th0rgal,
            365,
            custom_resolver.contract_address,
            ContractAddressZeroable::zero(),
            0,
            0
        );

    let domain = array![th0rgal].span();
    // by default we should have nothing written
    assert(naming.resolve(domain, 'starknet', array![].span()) == 0, 'non empty starknet field');
    // so it should resolve to the starknetid owner
    assert(naming.domain_to_address(domain, array![].span()) == caller, 'wrong domain target');

    let domain = array![1, 2, 3, th0rgal].span();

    // let's try the resolving
    assert(naming.resolve(domain, 'starknet', array![].span()) == 1 + 2 + 3, 'wrong target');
}
