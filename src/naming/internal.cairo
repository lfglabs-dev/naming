use core::array::SpanTrait;
use naming::{
    interface::referral::{IReferral, IReferralDispatcher, IReferralDispatcherTrait},
    naming::main::{
        Naming,
        Naming::{
            ContractStateEventEmitter, _hash_to_domainContractMemberStateTrait,
            _domain_dataContractMemberStateTrait, starknetid_contractContractMemberStateTrait,
            discountsContractMemberStateTrait, _address_to_domainContractMemberStateTrait,
            _referral_contractContractMemberStateTrait,
        }
    }
};
use identity::interface::identity::{IIdentity, IIdentityDispatcher, IIdentityDispatcherTrait};
use starknet::{
    contract_address::ContractAddressZeroable, ContractAddress, get_caller_address,
    get_contract_address
};
use openzeppelin::token::erc20::interface::{
    IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait
};
use naming::naming::utils::UtilsTrait;

#[generate_trait]
impl InternalImpl of InternalTrait {
    fn read_address_to_domain(
        self: @Naming::ContractState, address: ContractAddress, ref domain: Array<felt252>
    ) -> usize {
        let subdomain = self._address_to_domain.read((address, domain.len()));
        if subdomain == 0 {
            domain.len()
        } else {
            domain.append(subdomain);
            self.read_address_to_domain(address, ref domain)
        }
    }

    fn set_address_to_domain_util(
        ref self: Naming::ContractState, address: ContractAddress, mut domain: Span<felt252>
    ) {
        self._address_to_domain.write((address, domain.len()), 0);
        loop {
            match domain.pop_back() {
                Option::Some(domain_part) => {
                    self._address_to_domain.write((address, domain.len()), *domain_part);
                },
                Option::None => { break; }
            }
        };
    }

    // returns the custom resolver to use for a domain (0 if none)
    // and the parent domain length. If one parent domain has
    // reset its subdomains, it will break and return its length,
    // otherwise the parent length would be 0.
    fn domain_to_resolver(
        self: @Naming::ContractState, mut domain: Span<felt252>
    ) -> (ContractAddress, u32) {
        let mut custom_resolver = ContractAddressZeroable::zero();
        let mut parent_length = 0;
        let mut domain_parent_key = self._domain_data.read(self.hash_domain(domain)).parent_key;
        loop {
            if domain.len() == 1 {
                break;
            };
            // will fail on empty domain
            let parent_domain = domain.slice(1, domain.len() - 1);
            let hashed_parent_domain = self.hash_domain(parent_domain);
            let parent_domain_data = self._domain_data.read(hashed_parent_domain);
            if parent_domain_data.resolver.into() != 0 {
                custom_resolver = parent_domain_data.resolver;
                parent_length = parent_domain.len();
                break;
            }
            if domain_parent_key != parent_domain_data.key {
                // custom_resolver is zero
                parent_length = parent_domain.len();
                break;
            }
            domain = parent_domain;
            domain_parent_key = parent_domain_data.parent_key;
        };
        (custom_resolver, parent_length)
    }

    fn pay_domain(
        self: @Naming::ContractState,
        domain_len: usize,
        erc20: ContractAddress,
        price: u256,
        now: u64,
        days: u16,
        domain: felt252,
        sponsor: ContractAddress,
        discount_id: felt252
    ) -> () {
        // check the discount
        let discounted_price = if (discount_id == 0) {
            price
        } else {
            let discount = self.discounts.read(discount_id);
            let (min, max) = discount.domain_len_range;
            assert(min <= domain_len && domain_len <= max, 'invalid length for discount');

            let (min, max) = discount.days_range;
            assert(min <= days && days <= max, 'days out of discount range');

            let (min, max) = discount.timestamp_range;
            assert(min <= now && now <= max, 'time out of discount range');
            // discount.amount won't overflow as it's a value chosen by the admin to be in range (0, 100)
            (price * discount.amount) / 100
        };

        // pay the price
        let has_payed = IERC20CamelDispatcher { contract_address: erc20 }
            .transferFrom(get_caller_address(), get_contract_address(), discounted_price);
        assert(has_payed, 'payment failed');
        // add sponsor commission if eligible
        if sponsor.into() != 0 {
            IReferralDispatcher { contract_address: self._referral_contract.read() }
                .add_commission(
                    discounted_price,
                    sponsor,
                    sponsored_addr: get_caller_address(),
                    erc20_addr: erc20
                );
        }
    }

    fn mint_domain(
        ref self: Naming::ContractState,
        expiry: u64,
        resolver: ContractAddress,
        hashed_domain: felt252,
        id: u128,
        domain: felt252
    ) {
        let data = Naming::DomainData {
            owner: id,
            resolver,
            address: ContractAddressZeroable::zero(), // legacy native address
            expiry,
            key: 1,
            parent_key: 0,
        };
        self._hash_to_domain.write((hashed_domain, 0), domain);
        self._domain_data.write(hashed_domain, data);
        self.emit(Naming::Event::DomainMint(Naming::DomainMint { domain, owner: id, expiry }));

        IIdentityDispatcher { contract_address: self.starknetid_contract.read() }
            .set_verifier_data(id, 'name', hashed_domain, 0);
        if (resolver.into() != 0) {
            self
                .emit(
                    Naming::Event::DomainResolverUpdate(
                        Naming::DomainResolverUpdate { domain: array![domain].span(), resolver }
                    )
                );
        }
    }
}
