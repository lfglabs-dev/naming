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


#[starknet::contract]
mod ERC20 {
    use openzeppelin::token::erc20::erc20::ERC20Component::InternalTrait as ERC20InternalTrait;
    use openzeppelin::{
        token::erc20::{ERC20Component, dual20::DualCaseERC20Impl, ERC20HooksEmptyImpl}
    };

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("ether", "ETH");
        let target = starknet::contract_address_const::<0x123>();
        self.erc20._mint(target, 0x100000000000000000000000000000000);
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }
}

fn deploy() -> (IERC20CamelDispatcher, IPricingDispatcher, IIdentityDispatcher, INamingDispatcher) {
    //erc20
    // 0, 1 = low and high of ETH supply
    let eth = utils::deploy(ERC20::TEST_CLASS_HASH, array![]);

    // pricing
    let pricing = utils::deploy(Pricing::TEST_CLASS_HASH, array![eth.into()]);

    // identity
    let identity = utils::deploy(Identity::TEST_CLASS_HASH, array![0x123, 0, 0, 0]);

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

fn deploy_stark() -> IERC20CamelDispatcher {
    //erc20
    let stark = utils::deploy(ERC20::TEST_CLASS_HASH, array![]);
    IERC20CamelDispatcher { contract_address: stark }
}

fn deploy_with_erc20_fail() -> (IERC20CamelDispatcher, IPricingDispatcher, IIdentityDispatcher, INamingDispatcher) {
    //erc20
    let eth = utils::deploy(ERC20Fail::TEST_CLASS_HASH, array![]);

    // pricing
    let pricing = utils::deploy(Pricing::TEST_CLASS_HASH, array![eth.into()]);

    // identity
    let identity = utils::deploy(Identity::TEST_CLASS_HASH, array![0x123, 0, 0, 0]);

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

#[starknet::contract]
mod ERC20Fail {
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::erc20::ERC20Component::InternalTrait as ERC20InternalTrait;
    use openzeppelin::{
        token::erc20::{ERC20Component, dual20::DualCaseERC20Impl, ERC20HooksEmptyImpl}
    };

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("ether", "ETH");
        let target = starknet::contract_address_const::<0x123>();
        self.erc20._mint(target, 0x100000000000000000000000000000000);
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn transferFrom(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            false
        }
    }
}