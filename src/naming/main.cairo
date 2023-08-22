#[starknet::contract]
mod Naming {
    use option::OptionTrait;
    use starknet::ContractAddress;
    use starknet::contract_address::ContractAddressZeroable;
    use starknet::{get_caller_address, get_contract_address, get_block_timestamp};
    use traits::{Into, TryInto};
    use array::{ArrayTrait, SpanTrait};
    use zeroable::Zeroable;
    use starknet::class_hash::ClassHash;
    use integer::{u256_safe_divmod, u256_as_non_zero};
    use core::pedersen;
    use naming::interface::{
        naming::{INaming, INamingDispatcher, INamingDispatcherTrait},
        resolver::{IResolver, IResolverDispatcher, IResolverDispatcherTrait},
        pricing::{IPricing, IPricingDispatcher, IPricingDispatcherTrait},
        referral::{IReferral, IReferralDispatcher, IReferralDispatcherTrait},
    };
    use clone::Clone;
    use array::ArrayTCloneImpl;
    use identity::interface::identity::{IIdentity, IIdentityDispatcher, IIdentityDispatcherTrait};
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use debug::PrintTrait;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DomainOwner: DomainOwner,
        DomainToResolver: DomainToResolver,
        DomainTransfer: DomainTransfer,
        SaleMetadata: SaleMetadata,
    }

    #[derive(Drop, starknet::Event)]
    struct DomainOwner {
        #[key]
        domain: Array<felt252>,
        owner: u128,
        expiry: u64
    }

    #[derive(Drop, starknet::Event)]
    struct DomainToResolver {
        #[key]
        domain: Array<felt252>,
        resolver: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct DomainTransfer {
        #[key]
        domain: Span<felt252>,
        prev_owner: u128,
        new_owner: u128
    }

    #[derive(Drop, starknet::Event)]
    struct SaleMetadata {
        domain: felt252,
        metadata: felt252
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct DomainData {
        owner: u128, // an identity
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
        _referral_contract: ContractAddress,
        _admin_address: ContractAddress,
        _domain_data: LegacyMap<felt252, DomainData>,
        _hash_to_domain: LegacyMap<(felt252, usize), felt252>,
        _address_to_domain: LegacyMap<(ContractAddress, usize), felt252>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        starknetid: ContractAddress,
        pricing: ContractAddress,
        referral: ContractAddress,
        admin: ContractAddress
    ) {
        self.starknetid_contract.write(starknetid);
        self._pricing_contract.write(pricing);
        self._referral_contract.write(referral);
        self._admin_address.write(admin);
    }


    #[external(v0)]
    impl NamingImpl of INaming<ContractState> {
        fn buy(
            ref self: ContractState,
            id: u128,
            domain: felt252,
            days: u16,
            resolver: ContractAddress,
            sponsor: ContractAddress,
            metadata: felt252,
        ) {
            let (hashed_domain, now, expiry) = self.assert_purchase_is_possible(id, domain, days);
            self.pay_buy_domain(now, days, domain, sponsor);
            self.emit(Event::SaleMetadata(SaleMetadata { domain, metadata }));
            self.mint_domain(expiry, resolver, hashed_domain, id, domain);
        }

        fn transfer_domain(ref self: ContractState, domain: Span<felt252>, target_id: u128) {
            self.assert_control_domain(domain, get_caller_address());

            // Write domain owner
            let hashed_domain = self.hash_domain(domain);
            let current_domain_data = self._domain_data.read(hashed_domain);

            // ensure target doesn't already have a domain
            let now = get_block_timestamp();
            self.assert_id_availability(target_id, now);

            let new_domain_data = DomainData {
                owner: target_id,
                resolver: current_domain_data.resolver,
                address: current_domain_data.address,
                expiry: current_domain_data.expiry,
                key: current_domain_data.key,
                // no parent_domain check for root domains
                parent_key: if domain.len() == 1 {
                    current_domain_data.parent_key
                } else {
                    let hashed_parent_domain = self.hash_domain(domain.slice(1, domain.len() - 1));
                    let next_domain_data = self._domain_data.read(hashed_parent_domain);
                    next_domain_data.key
                }
            };

            self._domain_data.write(hashed_domain, new_domain_data);
            self
                .emit(
                    Event::DomainTransfer(
                        DomainTransfer {
                            domain: domain,
                            prev_owner: current_domain_data.owner,
                            new_owner: new_domain_data.owner
                        }
                    )
                );

            IIdentityDispatcher {
                contract_address: self.starknetid_contract.read()
            }.set_verifier_data(current_domain_data.owner, 'name', 0, 0);
            IIdentityDispatcher {
                contract_address: self.starknetid_contract.read()
            }.set_verifier_data(target_id, 'name', hashed_domain, 0);
            return;
        }

        // This function allows to read the single felt target of any domain for a specific field
        // For example, it allows to find the Bitcoin address of Alice.stark by calling
        // naming.resolve(['alice'], 'bitcoin')
        fn resolve(self: @ContractState, domain: Span<felt252>, field: felt252) -> felt252 {
            let (resolver, parent_start) = self.domain_to_resolver(domain, 0);
            if (resolver != ContractAddressZeroable::zero()) {
                IResolverDispatcher {
                    contract_address: resolver
                }.resolve(domain.slice(parent_start, domain.len() - parent_start), field)
            } else {
                let domain_data = self._domain_data.read(self.hash_domain(domain));
                IIdentityDispatcher {
                    contract_address: self.starknetid_contract.read()
                }.get_crosschecked_user_data(domain_data.owner, field)
            }
        }

        // This functions allows to resolve a domain to a native address. Its output is designed
        // to be used as a parameter for other functions (for example if you want to send ERC20
        // to a .stark)
        fn domain_to_address(self: @ContractState, domain: Span<felt252>) -> ContractAddress {
            let resolve_result = self.resolve(domain, 'starknet');
            if resolve_result != 0 {
                let addr: Option<ContractAddress> = resolve_result.try_into();
                return addr.unwrap();
            }
            let data = self._domain_data.read(self.hash_domain(domain));
            if data.address.into() != 0 {
                return data.address;
            }
            IIdentityDispatcher {
                contract_address: self.starknetid_contract.read()
            }.owner_of(data.owner)
        }

        // This returns the identity (StarknetID) owning the domain
        fn domain_to_id(self: @ContractState, domain: Span<felt252>) -> u128 {
            self._domain_data.read(self.hash_domain(domain)).owner
        }

        // This function allows to find which domain to use to display an account
        fn address_to_domain(self: @ContractState, address: ContractAddress) -> Array<felt252> {
            let mut domain = ArrayTrait::new();
            self._address_to_domain_util(address, ref domain);
            if domain.len() != 0 && self.domain_to_address(domain.span()) == address {
                domain
            } else {
                let identity = IIdentityDispatcher {
                    contract_address: self.starknetid_contract.read()
                };
                let id = identity.get_main_id(address);
                assert(id != 0, 'an id cannot be null');
                let id_hashed_domain = identity
                    .get_verifier_data(id, 'name', get_contract_address(), 0);
                let domain = self.unhash_domain(id_hashed_domain);
                assert(
                    self.domain_to_address(domain.span()) == address, 'domain not pointing back'
                );
                domain
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
            let y = self.hash_domain(domain.slice(0, new_len));
            let hashed_domain = pedersen(x, y);
            return hashed_domain;
        }

        fn unhash_domain(self: @ContractState, domain_hash: felt252) -> Array<felt252> {
            let mut i = 0;
            let mut domain = ArrayTrait::new();
            loop {
                let domain_part = self._hash_to_domain.read((domain_hash, i));
                if domain_part == 0 {
                    break;
                }
                domain.append(domain_part);
            };
            domain
        }

        fn assert_purchase_is_possible(
            self: @ContractState, identity: u128, domain: felt252, days: u16
        ) -> (felt252, u64, u64) {
            let now = get_block_timestamp();

            // Verify that the starknet.id doesn't already manage a domain
            self.assert_id_availability(identity, now);

            // Verify that the domain is not already taken or expired
            let hashed_domain = self.hash_domain(array![domain].span());
            let data = self._domain_data.read(hashed_domain);
            assert(data.owner == 0 || data.expiry < now, 'unexpired domain');

            // Verify expiration range
            assert(days < 365 * 25, 'max purchase of 25 years');
            assert(days > 2 * 30, 'min purchase of 2 month');
            return (hashed_domain, now, now + 86400 * days.into());
        }

        fn assert_control_domain(
            self: @ContractState, domain: Span<felt252>, account: ContractAddress
        ) {
            // 1. account owns the domain
            self._assert_is_owner(domain, account);
            // 2. check domain expiration
            let hashed_root_domain = self.hash_domain(domain.slice(domain.len() - 1, 1));
            let root_domain_data = self._domain_data.read(hashed_root_domain);
            assert(get_block_timestamp() <= root_domain_data.expiry, 'this domain has expired');
        }

        fn _assert_is_owner(
            self: @ContractState, domain: Span<felt252>, account: ContractAddress
        ) -> u32 {
            let hashed_domain = self.hash_domain(domain);
            let data = self._domain_data.read(hashed_domain);

            // because erc721 crashes on zero
            let owner = if data.owner == 0 {
                ContractAddressZeroable::zero()
            } else {
                IIdentityDispatcher {
                    contract_address: self.starknetid_contract.read()
                }.owner_of(data.owner)
            };

            // if caller owns the starknet id, he owns the domain, we return the key
            if owner == account {
                return data.key;
            }

            // otherwise, if it is a root domain, he doesn't own it
            assert(domain.len() != 1 && domain.len() != 0, 'you don\'t own this domain1');

            // if he doesn't own the starknet id, and doesn't own the domain, he might own the parent domain
            let parent_key = self._assert_is_owner(domain.slice(1, domain.len() - 1), account);
            // we ensure that the key is the same as the parent key
            // this is to allow to revoke all subdomains in o(1) writes, by juste updating the key of the parent
            if (data.parent_key != 0) {
                assert(parent_key == data.parent_key, 'you don\'t own this domain2');
            }
            data.key
        }

        // this ensures a non expired domain is not already written on this identity
        fn assert_id_availability(self: @ContractState, identity: u128, timestamp: u64) {
            let id_hashed_domain = IIdentityDispatcher {
                contract_address: self.starknetid_contract.read()
            }.get_verifier_data(identity, 'name', get_contract_address(), 0);
            assert(
                id_hashed_domain == 0
                    || self._domain_data.read(id_hashed_domain).expiry < timestamp,
                'this id holds a domain'
            );
        }

        fn _address_to_domain_util(
            self: @ContractState, address: ContractAddress, ref domain: Array<felt252>
        ) -> usize {
            let subdomain = self._address_to_domain.read((address, domain.len()));
            if subdomain == 0 {
                domain.len()
            } else {
                domain.append(subdomain);
                self._address_to_domain_util(address, ref domain)
            }
        }

        fn domain_to_resolver(
            self: @ContractState, domain: Span<felt252>, parent_start_id: u32
        ) -> (ContractAddress, u32) {
            if parent_start_id == domain.len() {
                return (ContractAddressZeroable::zero(), 0);
            }

            // hashing parent_domain
            let hashed_domain = self
                .hash_domain(domain.slice(parent_start_id, domain.len() - parent_start_id));

            let domain_data = self._domain_data.read(hashed_domain);

            if domain_data.resolver.into() != 0 {
                return (domain_data.resolver, parent_start_id);
            } else {
                return self.domain_to_resolver(domain, parent_start_id + 1);
            }
        }

        fn pay_buy_domain(
            self: @ContractState, now: u64, days: u16, domain: felt252, sponsor: ContractAddress
        ) -> () {
            // find domain cost
            let (erc20, price) = IPricingDispatcher {
                contract_address: self._pricing_contract.read()
            }.compute_buy_price(domain, days);

            // pay the price
            IERC20Dispatcher {
                contract_address: erc20
            }.transfer_from(get_caller_address(), get_contract_address(), price);
            // add sponsor commission if eligible
            if sponsor.into() != 0 {
                IReferralDispatcher {
                    contract_address: self._referral_contract.read()
                }.add_commission(price, sponsor);
            }
        }

        fn mint_domain(
            ref self: ContractState,
            expiry: u64,
            resolver: ContractAddress,
            hashed_domain: felt252,
            id: u128,
            domain: felt252
        ) {
            let data = DomainData {
                owner: id,
                resolver,
                address: ContractAddressZeroable::zero(), // legacy native address
                expiry,
                key: 1,
                parent_key: 0,
            };
            self._hash_to_domain.write((hashed_domain, 0), hashed_domain);
            self._domain_data.write(hashed_domain, data);
            let mut domain_arr = array![domain];
            self
                .emit(
                    Event::DomainOwner(
                        DomainOwner { domain: domain_arr.clone(), owner: id, expiry }
                    )
                );

            IIdentityDispatcher {
                contract_address: self.starknetid_contract.read()
            }.set_verifier_data(id, 'name', hashed_domain, 0);
            if (resolver.into() != 0) {
                self
                    .emit(
                        Event::DomainToResolver(DomainToResolver { domain: domain_arr, resolver })
                    );
            }
        }
    }
}
