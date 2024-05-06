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
use naming::interface::auto_renewal::{
    IAutoRenewal, IAutoRenewalDispatcher, IAutoRenewalDispatcherTrait
};
use naming::naming::main::Naming;
use naming::pricing::Pricing;
use super::common::deploy;
use naming::naming::main::Naming::Discount;


#[starknet::contract]
mod DummyAutoRenewal {
    use core::array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::{contract_address_const, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        erc20: starknet::ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, erc20: starknet::ContractAddress) {
        self.erc20.write(erc20);
    }

    #[abi(embed_v0)]
    impl DummyImpl of naming::interface::auto_renewal::IAutoRenewal<ContractState> {
        fn get_renewing_allowance(
            self: @ContractState, domain: felt252, renewer: starknet::ContractAddress,
        ) -> u256 {
            1
        }

        // naming, erc20, tax
        fn get_contracts(
            self: @ContractState
        ) -> (starknet::ContractAddress, starknet::ContractAddress, starknet::ContractAddress) {
            (contract_address_const::<0x0>(), self.erc20.read(), contract_address_const::<0x0>())
        }
    }
}

#[test]
#[available_gas(2000000000)]
fn test_ar_discount() {
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

    let auto_renewal = utils::deploy(
        DummyAutoRenewal::TEST_CLASS_HASH, array![eth.contract_address.into()]
    );

    let current_expiry = naming.domain_to_expiry(array![th0rgal].span());

    // we set the renewal contract and enable the discount
    naming.whitelist_renewal_contract(auto_renewal);
    naming.toggle_ar_discount_renew();
    let (_, yearly_renewal_price) = pricing.compute_renew_price(7, 365);
    eth.approve(auto_renewal, yearly_renewal_price);
    let _allowance = eth.allowance(caller, auto_renewal);
    naming.ar_discount_renew(th0rgal, auto_renewal);

    // we don't set the auto renewal allowance in this test because we 
    // use a dummy contract which always return 1, theoretically we should
    // set it to infinity (2**256-1)
    let new_expiry = naming.domain_to_expiry(array![th0rgal].span());
    assert(new_expiry - current_expiry == 86400 * 90, 'Invalid expiry');
}


#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Discount disabled', 'ENTRYPOINT_FAILED'))]
fn test_ar_discount_not_enabled() {
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

    let auto_renewal = utils::deploy(
        DummyAutoRenewal::TEST_CLASS_HASH, array![eth.contract_address.into()]
    );

    // we set the renewal contract and don't enable the discount
    naming.whitelist_renewal_contract(auto_renewal);
    //naming.toggle_ar_discount_renew();
    let (_, yearly_renewal_price) = pricing.compute_renew_price(7, 365);
    eth.approve(auto_renewal, yearly_renewal_price);
    let _allowance = eth.allowance(caller, auto_renewal);
    naming.ar_discount_renew(th0rgal, auto_renewal);
}


#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Invalid ERC20 allowance', 'ENTRYPOINT_FAILED'))]
fn test_ar_discount_wrong_ar_allowance() {
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

    let auto_renewal = utils::deploy(
        DummyAutoRenewal::TEST_CLASS_HASH, array![eth.contract_address.into()]
    );

    let current_expiry = naming.domain_to_expiry(array![th0rgal].span());

    // we set the renewal contract and enable the discount
    naming.whitelist_renewal_contract(auto_renewal);
    naming.toggle_ar_discount_renew();
    let (_, _yearly_renewal_price) = pricing.compute_renew_price(7, 365);
    //eth.approve(auto_renewal, yearly_renewal_price);
    let _allowance = eth.allowance(caller, auto_renewal);
    naming.ar_discount_renew(th0rgal, auto_renewal);

    // we don't set the auto renewal allowance in this test because we 
    // use a dummy contract which always return 1, theoretically we should
    // set it to infinity (2**256-1)
    let new_expiry = naming.domain_to_expiry(array![th0rgal].span());
    assert(new_expiry - current_expiry == 86400 * 90, 'Invalid expiry');
}
