use core::array::SpanTrait;
#[starknet::contract]
mod Naming {
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;
    use starknet::{get_caller_address, get_contract_address};
    use traits::Into;
    use array::{ArrayTrait, SpanTrait};
    use zeroable::Zeroable;
    use starknet::class_hash::ClassHash;
    use naming::interface::{
        naming::{INaming, INamingDispatcher, INamingDispatcherTrait},
        resolver::{IResolver, IResolverDispatcher, IResolverDispatcherTrait},
        identity::{IIdentity, IIdentityDispatcher, IIdentityDispatcherTrait}
    };
    use integer::{u256_safe_divmod, u256_as_non_zero};
    use core::pedersen;

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct DomainData {
        owner: felt252, // an identity
        resolver: ContractAddress,
        address: ContractAddress, // the legacy native address
        expiry: u64, // expiration date
        key: u32, // a uniq id, updated on transfer
        parent_key: u32, // key of parent domain
    }

    #[storage]
    struct Storage {
        starknetid_contract: ContractAddress,
        _pricing_contract: ContractAddress,
        _admin_address: ContractAddress,
        _domain_data: LegacyMap<felt252, DomainData>,
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
    impl NamingImpl of INaming<ContractState> {
        // This function allows to read the single felt target of any domain for a specific field
        // For example, it allows to find the Bitcoin address of Alice.stark by calling
        // naming.resolve(['alice'], 'bitcoin')
        fn resolve(self: @ContractState, domain: Array<felt252>, field: felt252) -> felt252 {
            let (resolver, parent_start) = self.domain_to_resolver(@domain, 0);
            if (resolver != ContractAddressZeroable::zero()) {
                IResolverDispatcher {
                    contract_address: resolver
                }.resolve(domain.span().slice(parent_start, domain.len() - parent_start), field)
            } else {
                let domain_data = self._domain_data.read(self.hash_domain(domain.span()));
                IIdentityDispatcher {
                    contract_address: self.starknetid_contract.read()
                }.get_crosschecked_user_data(domain_data.owner, field)
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn hash_domain(self: @ContractState, domain: Span<felt252>) -> felt252 {
            if domain.len() == 0 {
                return 0;
            }
            let new_len = domain.len() - 1;
            let x = *domain[new_len];
            let y = self.hash_domain(domain);
            let hashed_domain = pedersen(x, y);
            return hashed_domain;
        }

        fn domain_to_resolver(
            self: @ContractState, domain: @Array<felt252>, parent_start_id: u32
        ) -> (ContractAddress, u32) {
            if parent_start_id == domain.len() {
                return (ContractAddressZeroable::zero(), 0);
            }

            // hashing parent_domain
            let hashed_domain = self
                .hash_domain(domain.span().slice(parent_start_id, domain.len() - parent_start_id));

            let domain_data = self._domain_data.read(hashed_domain);

            if domain_data.resolver.into() != 0 {
                return (domain_data.resolver, parent_start_id);
            } else {
                return self.domain_to_resolver(domain, parent_start_id + 1);
            }
        }
    }
}
