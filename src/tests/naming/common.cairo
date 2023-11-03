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
    erc20::ERC20, interface::{IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
};
use identity::{
    identity::main::Identity, interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait}
};
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use naming::interface::pricing::{IPricingDispatcher, IPricingDispatcherTrait};
use naming::naming::main::Naming;
use naming::pricing::Pricing;

fn deploy() -> (IERC20CamelDispatcher, IPricingDispatcher, IIdentityDispatcher, INamingDispatcher) {
    //erc20
    // 0, 1 = low and high of ETH supply
    let eth = utils::deploy(ERC20::TEST_CLASS_HASH, array!['ether', 'ETH', 0, 1, 0x123]);

    // pricing
    let pricing = utils::deploy(Pricing::TEST_CLASS_HASH, array![eth.into()]);

    // identity
    let identity = utils::deploy(Identity::TEST_CLASS_HASH, array![0]);

    // naming
    let admin = 0x123;
    let address = utils::deploy(
        Naming::TEST_CLASS_HASH, array![identity.into(), pricing.into(), 0, admin]
    );
    (
        IERC20CamelDispatcher { contract_address: eth },
        IPricingDispatcher { contract_address: pricing },
        IIdentityDispatcher { contract_address: identity },
        INamingDispatcher { contract_address: address }
    )
}
