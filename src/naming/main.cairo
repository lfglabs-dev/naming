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
    use core::pedersen;
    use hash::LegacyHash;
    use ecdsa::check_ecdsa_signature;
    use wadray::Wad;
    use naming::{
        naming::{asserts::AssertionsTrait, internal::InternalTrait, utils::UtilsTrait},
        interface::{
            naming::{INaming, INamingDispatcher, INamingDispatcherTrait},
            pricing::{IPricing, IPricingDispatcher, IPricingDispatcherTrait},
            auto_renewal::{IAutoRenewal, IAutoRenewalDispatcher, IAutoRenewalDispatcherTrait}
        }
    };
    use identity::interface::identity::{IIdentity, IIdentityDispatcher, IIdentityDispatcherTrait};
    use openzeppelin::{
        access::ownable::OwnableComponent,
        token::erc20::interface::{IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
    };
    use storage_read::{main::storage_read_component, interface::IStorageRead};

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DomainMint: DomainMint,
        DomainRenewal: DomainRenewal,
        DomainResolverUpdate: DomainResolverUpdate,
        LegacyDomainToAddressClear: LegacyDomainToAddressClear,
        AddressToDomainUpdate: AddressToDomainUpdate,
        DomainTransfer: DomainTransfer,
        DomainMigrated: DomainMigrated,
        SubdomainsReset: SubdomainsReset,
        SaleMetadata: SaleMetadata,
        StorageReadEvent: storage_read_component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct DomainMint {
        #[key]
        domain: felt252,
        owner: u128,
        expiry: u64
    }

    #[derive(Drop, starknet::Event)]
    struct DomainRenewal {
        #[key]
        domain: felt252,
        new_expiry: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct DomainResolverUpdate {
        #[key]
        domain: Span<felt252>,
        resolver: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct LegacyDomainToAddressClear {
        #[key]
        domain: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressToDomainUpdate {
        #[key]
        address: ContractAddress,
        domain: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct DomainTransfer {
        #[key]
        domain: Span<felt252>,
        prev_owner: u128,
        new_owner: u128
    }

    #[derive(Drop, starknet::Event)]
    struct DomainMigrated {
        #[key]
        domain: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct SubdomainsReset {
        #[key]
        domain: Span<felt252>,
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

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Discount {
        domain_len_range: (usize, usize),
        days_range: (u16, u16),
        timestamp_range: (u64, u64),
        amount: u256, // this is actually the amount to pay in % after discount
    }

    #[storage]
    struct Storage {
        discounts: LegacyMap<felt252, Discount>,
        starknetid_contract: ContractAddress,
        _pricing_contract: ContractAddress,
        _referral_contract: ContractAddress,
        _admin_address: ContractAddress,
        _domain_data: LegacyMap<felt252, DomainData>,
        _hash_to_domain: LegacyMap<(felt252, usize), felt252>,
        _address_to_domain: LegacyMap<(ContractAddress, usize), felt252>,
        _server_pub_key: felt252,
        _whitelisted_renewal_contracts: LegacyMap<ContractAddress, bool>,
        // a for alpha, as we will probably do this campaign again in the future
        _ar_discount_blacklist_a: LegacyMap<felt252, bool>,
        _ar_discount_renew_enabled: bool,
        #[substorage(v0)]
        storage_read: storage_read_component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
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
        self.ownable.initializer(admin);
    }

    component!(path: storage_read_component, storage: storage_read, event: StorageReadEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl StorageReadComponent = storage_read_component::StorageRead<ContractState>;
    #[abi(embed_v0)]
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl NamingImpl of INaming<ContractState> {
        // VIEW

        // This function allows to read the single felt target of any domain for a specific field
        // For example, it allows to find the Bitcoin address of Alice.stark by calling
        // naming.resolve(['alice'], 'bitcoin')
        // Use it with caution in smartcontracts as it can call untrusted contracts
        fn resolve(
            self: @ContractState, domain: Span<felt252>, field: felt252, hint: Span<felt252>
        ) -> felt252 {
            let (_, value) = self.resolve_util(domain, field, hint);
            value
        }

        // This functions allows to resolve a domain to a native address. Its output is designed
        // to be used as a parameter for other functions (for example if you want to send ERC20
        // to a .stark)
        fn domain_to_address(
            self: @ContractState, domain: Span<felt252>, hint: Span<felt252>
        ) -> ContractAddress {
            // resolve must be performed first because it calls untrusted resolving contracts
            let (hashed_domain, value) = self.resolve_util(domain, 'starknet', hint);
            if value != 0 {
                let addr: Option<ContractAddress> = value.try_into();
                return addr.unwrap();
            };
            let data = self._domain_data.read(hashed_domain);
            if data.address.into() != 0 {
                if domain.len() != 1 {
                    let parent_key = self
                        ._domain_data
                        .read(self.hash_domain(domain.slice(1, domain.len() - 1)))
                        .key;
                    if parent_key == data.parent_key {
                        return data.address;
                    };
                };
                return data.address;
            };
            IIdentityDispatcher { contract_address: self.starknetid_contract.read() }
                .owner_from_id(self.domain_to_id(domain))
        }

        // This returns the stored DomainData associated to this domain
        fn domain_to_data(self: @ContractState, domain: Span<felt252>) -> DomainData {
            self._domain_data.read(self.hash_domain(domain))
        }

        // This returns the expiry associated to this domain
        fn domain_to_expiry(self: @ContractState, domain: Span<felt252>) -> u64 {
            self._domain_data.read(self.hash_domain(domain)).expiry
        }

        // This returns the identity (StarknetID) owning the domain
        fn domain_to_id(self: @ContractState, domain: Span<felt252>) -> u128 {
            let data = self._domain_data.read(self.hash_domain(domain));
            // todo: revert when try catch are available 
            if domain.len() == 0 {
                return 0;
            };
            if domain.len() != 1 {
                let parent_key = self
                    ._domain_data
                    .read(self.hash_domain(domain.slice(1, domain.len() - 1)))
                    .key;
                if parent_key != data.parent_key {
                    return 0;
                };
            };
            data.owner
        }

        // This function allows to find which domain to use to display an account
        fn address_to_domain(
            self: @ContractState, address: ContractAddress, hint: Span<felt252>
        ) -> Span<felt252> {
            let mut domain = ArrayTrait::new();
            self.read_address_to_domain(address, ref domain);
            if domain.len() != 0 && self.domain_to_address(domain.span(), hint) == address {
                domain.span()
            } else {
                let identity = IIdentityDispatcher {
                    contract_address: self.starknetid_contract.read()
                };
                let id = identity.get_main_id(address);
                // todo: revert when try catch are available
                // assert(id != 0, 'an id cannot be null');
                if id == 0 {
                    return array![].span();
                }
                let id_hashed_domain = identity
                    .get_verifier_data(id, 'name', get_contract_address(), 0);
                let domain = self.unhash_domain(id_hashed_domain);
                // todo: revert when try catch are available
                // assert(
                //     self.domain_to_address(domain, array![].span()) == address,
                //     'domain not pointing back'
                // );
                if self.domain_to_address(domain, array![].span()) != address {
                    return array![].span();
                }
                domain
            }
        }

        // EXTERNAL

        fn buy(
            ref self: ContractState,
            id: u128,
            domain: felt252,
            days: u16,
            resolver: ContractAddress,
            sponsor: ContractAddress,
            discount_id: felt252,
            metadata: felt252,
        ) {
            let (hashed_domain, now, expiry) = self.assert_purchase_is_possible(id, domain, days);
            // we need a u256 to be able to perform safe divisions
            let domain_len = self.get_chars_len(domain.into());
            assert(domain_len != 0, 'domain can\'t be empty');
            // find domain cost
            let (erc20, price) = IPricingDispatcher {
                contract_address: self._pricing_contract.read()
            }
                .compute_buy_price(domain_len, days);
            self.pay_domain(domain_len, erc20, price, now, days, domain, sponsor, discount_id);
            self.emit(Event::SaleMetadata(SaleMetadata { domain, metadata }));
            self.mint_domain(expiry, resolver, hashed_domain, id, domain);
        }

        fn altcoin_buy(
            ref self: ContractState,
            id: u128,
            domain: felt252,
            days: u16,
            resolver: ContractAddress,
            sponsor: ContractAddress,
            discount_id: felt252,
            metadata: felt252,
            altcoin_addr: ContractAddress,
            quote: Wad,
            max_validity: u64,
            sig: (felt252, felt252),
        ) {
            let (hashed_domain, now, expiry) = self.assert_purchase_is_possible(id, domain, days);
            // we need a u256 to be able to perform safe divisions
            let domain_len = self.get_chars_len(domain.into());
            assert(domain_len != 0, 'domain can\'t be empty');

            // check quote timestamp is still valid
            assert(get_block_timestamp() <= max_validity, 'quotation expired');

            // verify signature
            let altcoin: felt252 = altcoin_addr.into();
            let quote_felt: felt252 = quote.into();
            let message_hash = LegacyHash::hash(
                LegacyHash::hash(LegacyHash::hash(altcoin, quote_felt), max_validity),
                'starknet id altcoin quote'
            );
            let (sig0, sig1) = sig;
            let is_valid = check_ecdsa_signature(
                message_hash, self._server_pub_key.read(), sig0, sig1
            );
            assert(is_valid, 'Invalid signature');

            // find domain cost in ETH
            let (_, price_in_eth) = IPricingDispatcher {
                contract_address: self._pricing_contract.read()
            }
                .compute_buy_price(domain_len, days);
            // compute domain cost in altcoin
            let price_in_altcoin = self.get_altcoin_price(quote, price_in_eth.try_into().unwrap());
            self
                .pay_domain(
                    domain_len,
                    altcoin_addr,
                    price_in_altcoin,
                    now,
                    days,
                    domain,
                    sponsor,
                    discount_id
                );
            self.emit(Event::SaleMetadata(SaleMetadata { domain, metadata }));
            self.mint_domain(expiry, resolver, hashed_domain, id, domain);
        }

        fn renew(
            ref self: ContractState,
            domain: felt252,
            days: u16,
            sponsor: ContractAddress,
            discount_id: felt252,
            metadata: felt252,
        ) {
            let now = get_block_timestamp();
            let hashed_domain = self.hash_domain(array![domain].span());
            let domain_data = self._domain_data.read(hashed_domain);

            // we need a u256 to be able to perform safe divisions
            let domain_len = self.get_chars_len(domain.into());
            // find domain cost
            let (erc20, price) = IPricingDispatcher {
                contract_address: self._pricing_contract.read()
            }
                .compute_renew_price(domain_len, days);
            self.pay_domain(domain_len, erc20, price, now, days, domain, sponsor, discount_id);
            self.emit(Event::SaleMetadata(SaleMetadata { domain, metadata }));
            // find new domain expiry
            let new_expiry = if domain_data.expiry <= now {
                now + 86400 * days.into()
            } else {
                domain_data.expiry + 86400 * days.into()
            };
            // 25*365 = 9125
            assert(new_expiry <= now + 86400 * 9125, 'purchase too long');
            assert(days >= 6 * 30, 'purchase too short');

            let data = DomainData {
                owner: domain_data.owner,
                resolver: domain_data.resolver,
                address: domain_data.address,
                expiry: new_expiry,
                key: domain_data.key,
                parent_key: 0,
            };
            self._domain_data.write(hashed_domain, data);
            self.emit(Event::DomainRenewal(DomainRenewal { domain, new_expiry }));
        }

        fn altcoin_renew(
            ref self: ContractState,
            domain: felt252,
            days: u16,
            sponsor: ContractAddress,
            discount_id: felt252,
            metadata: felt252,
            altcoin_addr: ContractAddress,
            quote: Wad,
            max_validity: u64,
            sig: (felt252, felt252),
        ) {
            let now = get_block_timestamp();
            let hashed_domain = self.hash_domain(array![domain].span());
            let domain_data = self._domain_data.read(hashed_domain);

            // check quote timestamp is still valid
            assert(get_block_timestamp() <= max_validity, 'quotation expired');
            // verify signature
            let altcoin: felt252 = altcoin_addr.into();
            let quote_felt: felt252 = quote.into();
            let message_hash = LegacyHash::hash(
                LegacyHash::hash(LegacyHash::hash(altcoin, quote_felt), max_validity),
                'starknet id altcoin quote'
            );
            let (sig0, sig1) = sig;
            let is_valid = check_ecdsa_signature(
                message_hash, self._server_pub_key.read(), sig0, sig1
            );
            assert(is_valid, 'Invalid signature');

            // we need a u256 to be able to perform safe divisions
            let domain_len = self.get_chars_len(domain.into());
            // find domain cost in ETH
            let (_, price_in_eth) = IPricingDispatcher {
                contract_address: self._pricing_contract.read()
            }
                .compute_renew_price(domain_len, days);
            // compute domain cost in altcoin
            let price_in_altcoin = self.get_altcoin_price(quote, price_in_eth.try_into().unwrap());
            self
                .pay_domain(
                    domain_len,
                    altcoin_addr,
                    price_in_altcoin,
                    now,
                    days,
                    domain,
                    sponsor,
                    discount_id
                );
            self.emit(Event::SaleMetadata(SaleMetadata { domain, metadata }));
            // find new domain expiry
            let new_expiry = if domain_data.expiry <= now {
                now + 86400 * days.into()
            } else {
                domain_data.expiry + 86400 * days.into()
            };
            // 25*365 = 9125
            assert(new_expiry <= now + 86400 * 9125, 'purchase too long');
            assert(days >= 6 * 30, 'purchase too short');

            let data = DomainData {
                owner: domain_data.owner,
                resolver: domain_data.resolver,
                address: domain_data.address,
                expiry: new_expiry,
                key: domain_data.key,
                parent_key: 0,
            };
            self._domain_data.write(hashed_domain, data);
            self.emit(Event::DomainRenewal(DomainRenewal { domain, new_expiry }));
        }

        fn ar_discount_renew(
            ref self: ContractState, domain: felt252, ar_contract: ContractAddress,
        ) {
            // First we check the discount is enabled
            assert(self._ar_discount_renew_enabled.read(), 'Discount disabled');

            // We check that domain didn't already claim the discount
            assert(!self._ar_discount_blacklist_a.read(domain), 'You can\'t claim this twice');

            // We check it's a valid AR contract, then we check that AR is enabled,
            // we don't validate the pricing because it could change
            assert(self._whitelisted_renewal_contracts.read(ar_contract), 'AR not whitelisted');
            let auto_renewal_dispatcher = IAutoRenewalDispatcher { contract_address: ar_contract };
            let caller = get_caller_address();
            let ar_allowance = auto_renewal_dispatcher.get_renewing_allowance(domain, caller);
            assert(ar_allowance != 0, 'Invalid AR allowance');
            let (_, erc20, _) = auto_renewal_dispatcher.get_contracts();
            let erc20_allowance = IERC20CamelDispatcher { contract_address: erc20 }
                .allowance(caller, ar_contract);
            assert(erc20_allowance != 0, 'Invalid ERC20 allowance');

            // We then blacklist that domain for this discount
            self._ar_discount_blacklist_a.write(domain, true);

            // We can finally renew the domain with no SaleMetadata event since it's free
            let now = get_block_timestamp();
            let hashed_domain = self.hash_domain(array![domain].span());
            let domain_data = self._domain_data.read(hashed_domain);
            // we extended its expiry by 90 days (~3 months)
            let new_expiry = if domain_data.expiry <= now {
                now + 86400 * 90
            } else {
                domain_data.expiry + 86400 * 90
            };

            let data = DomainData {
                owner: domain_data.owner,
                resolver: domain_data.resolver,
                address: domain_data.address,
                expiry: new_expiry,
                key: domain_data.key,
                parent_key: 0,
            };
            self._domain_data.write(hashed_domain, data);
            self.emit(Event::DomainRenewal(DomainRenewal { domain, new_expiry }));
        }

        fn auto_renew_altcoin(
            ref self: ContractState,
            domain: felt252,
            days: u16,
            sponsor: ContractAddress,
            discount_id: felt252,
            metadata: felt252,
            altcoin_addr: ContractAddress,
            price_in_altcoin: u256,
        ) {
            let now = get_block_timestamp();
            let hashed_domain = self.hash_domain(array![domain].span());
            let domain_data = self._domain_data.read(hashed_domain);

            // check caller is a whitelisted altcoin auto renewal contract
            assert(
                self._whitelisted_renewal_contracts.read(get_caller_address()),
                'Caller not whitelisted'
            );

            // we need a u256 to be able to perform safe divisions
            let domain_len = self.get_chars_len(domain.into());
            self
                .pay_domain(
                    domain_len,
                    altcoin_addr,
                    price_in_altcoin,
                    now,
                    days,
                    domain,
                    sponsor,
                    discount_id
                );
            self.emit(Event::SaleMetadata(SaleMetadata { domain, metadata }));
            // find new domain expiry
            let new_expiry = if domain_data.expiry <= now {
                now + 86400 * days.into()
            } else {
                domain_data.expiry + 86400 * days.into()
            };

            let data = DomainData {
                owner: domain_data.owner,
                resolver: domain_data.resolver,
                address: domain_data.address,
                expiry: new_expiry,
                key: domain_data.key,
                parent_key: 0,
            };
            self._domain_data.write(hashed_domain, data);
            self.emit(Event::DomainRenewal(DomainRenewal { domain, new_expiry }));
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

            // if a subdomain is created
            if self._hash_to_domain.read((hashed_domain, 0)) == 0 {
                self.store_unhashed_domain(domain, hashed_domain);
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

            // identity contract is trusted
            IIdentityDispatcher { contract_address: self.starknetid_contract.read() }
                .set_verifier_data(current_domain_data.owner, 'name', 0, 0);
            IIdentityDispatcher { contract_address: self.starknetid_contract.read() }
                .set_verifier_data(target_id, 'name', hashed_domain, 0);
        }

        fn reset_subdomains(ref self: ContractState, domain: Span<felt252>) {
            self.assert_control_domain(domain, get_caller_address());
            let hashed_domain = self.hash_domain(domain);
            let current_domain_data = self._domain_data.read(hashed_domain);
            let new_domain_data = DomainData {
                owner: current_domain_data.owner,
                resolver: current_domain_data.resolver,
                address: current_domain_data.address,
                expiry: current_domain_data.expiry,
                key: current_domain_data.key + 1,
                parent_key: current_domain_data.parent_key,
            };
            self._domain_data.write(hashed_domain, new_domain_data);
            self.emit(Event::SubdomainsReset(SubdomainsReset { domain: domain, }));
        }


        // will override your main id
        fn set_address_to_domain(
            ref self: ContractState, domain: Span<felt252>, hint: Span<felt252>
        ) {
            let address = get_caller_address();
            assert(self.domain_to_address(domain, hint) == address, 'domain not pointing back');
            self.emit(Event::AddressToDomainUpdate(AddressToDomainUpdate { address, domain }));
            self.set_address_to_domain_util(address, domain);
        }

        // this allows to reset the target set via Cairo Zero, can't be tested
        fn clear_legacy_domain_to_address(ref self: ContractState, domain: Span<felt252>) {
            let address = get_caller_address();
            self.assert_control_domain(domain, address);
            self.emit(Event::LegacyDomainToAddressClear(LegacyDomainToAddressClear { domain }));
            let hashed_domain = self.hash_domain(domain);
            let current_domain_data = self._domain_data.read(hashed_domain);
            let new_domain_data = DomainData {
                owner: current_domain_data.owner,
                resolver: current_domain_data.resolver,
                address: ContractAddressZeroable::zero(),
                expiry: current_domain_data.expiry,
                key: current_domain_data.key,
                parent_key: current_domain_data.parent_key,
            };
            self._domain_data.write(hashed_domain, new_domain_data);
        }

        fn reset_address_to_domain(ref self: ContractState) {
            let address = get_caller_address();
            self
                .emit(
                    Event::AddressToDomainUpdate(
                        AddressToDomainUpdate { address, domain: array![].span() }
                    )
                );
            self.set_address_to_domain_util(address, array![0].span());
        }

        // allows to unhash domains minted in Cairo Zero
        fn migrate_domain(ref self: ContractState, domain: Span<felt252>) {
            let hashed_domain = self.hash_domain(domain);
            self.store_unhashed_domain(domain, hashed_domain);
            self.emit(Event::DomainMigrated(DomainMigrated { domain }));
        }

        fn set_domain_to_resolver(
            ref self: ContractState, domain: Span<felt252>, resolver: ContractAddress
        ) {
            self.assert_control_domain(domain, get_caller_address());

            // Write domain owner
            let hashed_domain = self.hash_domain(domain);
            let current_domain_data = self._domain_data.read(hashed_domain);
            let new_domain_data = DomainData {
                owner: current_domain_data.owner,
                resolver,
                address: current_domain_data.address,
                expiry: current_domain_data.expiry,
                key: current_domain_data.key,
                parent_key: current_domain_data.parent_key,
            };
            self._domain_data.write(hashed_domain, new_domain_data);
            self.emit(Event::DomainResolverUpdate(DomainResolverUpdate { domain, resolver }));
        }

        // ADMIN

        fn update_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(get_caller_address() == self._admin_address.read(), 'you are not admin');
            self.ownable.initializer(new_admin);
            self._admin_address.write(Zeroable::zero());
        }

        fn set_expiry(
            ref self: ContractState, root_domain: felt252, expiry: u64
        ) {
            self.ownable.assert_only_owner();
            let hashed_domain = self.hash_domain(array![root_domain].span());
            let domain_data = self._domain_data.read(hashed_domain);
            let data = DomainData {
                owner: domain_data.owner,
                resolver: domain_data.resolver,
                address: domain_data.address,
                expiry: expiry,
                key: domain_data.key,
                parent_key: 0,
            };
            self._domain_data.write(hashed_domain, data);
            self
                .emit(
                    Event::DomainRenewal(DomainRenewal { domain: root_domain, new_expiry: expiry })
                );
        }

        fn claim_balance(ref self: ContractState, erc20: ContractAddress) {
            self.ownable.assert_only_owner();
            let balance = IERC20CamelDispatcher { contract_address: erc20 }
                .balanceOf(get_contract_address());
            let has_claimed = IERC20CamelDispatcher { contract_address: erc20 }
                .transfer(get_caller_address(), balance);
            assert(has_claimed, 'Claim failed');
        }

        fn set_discount(ref self: ContractState, discount_id: felt252, discount: Discount) {
            self.ownable.assert_only_owner();
            self.discounts.write(discount_id, discount);
        }

        fn set_pricing_contract(ref self: ContractState, pricing_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self._pricing_contract.write(pricing_contract);
        }

        fn set_referral_contract(ref self: ContractState, referral_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self._referral_contract.write(referral_contract);
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            // todo: use components
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap();
        }

        fn set_server_pub_key(ref self: ContractState, new_key: felt252) {
            self.ownable.assert_only_owner();
            self._server_pub_key.write(new_key);
        }

        fn whitelist_renewal_contract(ref self: ContractState, contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self._whitelisted_renewal_contracts.write(contract, true);
        }

        fn blacklist_renewal_contract(ref self: ContractState, contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self._whitelisted_renewal_contracts.write(contract, false);
        }


        fn toggle_ar_discount_renew(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self._ar_discount_renew_enabled.write(!self._ar_discount_renew_enabled.read());
        }
    }
}

