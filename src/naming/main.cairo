#[starknet::contract]
mod Naming {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use traits::Into;
    use array::{ArrayTrait};
    use zeroable::Zeroable;
    use starknet::class_hash::ClassHash;
    use naming::interface::naming::{INaming, INamingDispatcher, INamingDispatcherTrait};
    use integer::{u256_safe_divmod, u256_as_non_zero};

    #[storage]
    struct Storage {
        starknetid_contract: ContractAddress,
        _pricing_contract: ContractAddress,
        _admin_address: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        starknetid: ContractAddress,
        pricing: ContractAddress,
        admin: ContractAddress
    ) {
        self.starknetid_contract.write(starknetid);
        self._pricing_contract.write(pricing);
        self._admin_address.write(admin);
    }


    #[external(v0)]
    impl PricingImpl of INaming<ContractState> {
        fn resolve(self: @ContractState, domain: felt252, field: felt252) -> felt252 {
            1
        }
    }
}
