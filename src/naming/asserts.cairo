use naming::{
    interface::{
        naming::{INaming, INamingDispatcher, INamingDispatcherTrait},
        resolver::{IResolver, IResolverDispatcher, IResolverDispatcherTrait},
        pricing::{IPricing, IPricingDispatcher, IPricingDispatcherTrait},
        referral::{IReferral, IReferralDispatcher, IReferralDispatcherTrait},
    },
    naming::main::{
        Naming,
        Naming::{
            ContractStateEventEmitter, _hash_to_domain, _hash_to_domainContractMemberStateTrait,
            _domain_data, _domain_dataContractMemberStateTrait, starknetid_contract,
            starknetid_contractContractMemberStateTrait, discounts,
            discountsContractMemberStateTrait, _address_to_domain,
            _address_to_domainContractMemberStateTrait, _referral_contract,
            _referral_contractContractMemberStateTrait,
        }
    },
};
use identity::interface::identity::{IIdentity, IIdentityDispatcher, IIdentityDispatcherTrait};
use starknet::{
    contract_address::ContractAddressZeroable, ContractAddress, get_caller_address,
    get_contract_address, get_block_timestamp
};
use openzeppelin::token::erc20::interface::{
    IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait
};
use integer::{u256_safe_divmod, u256_as_non_zero};
use naming::naming::utils::UtilsTrait;


#[generate_trait]
impl AssertionsImpl of AssertionsTrait {
    fn assert_purchase_is_possible(
        self: @Naming::ContractState, identity: u128, domain: felt252, days: u16
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
        self: @Naming::ContractState, domain: Span<felt252>, account: ContractAddress
    ) {
        // 1. account owns the domain
        self.assert_is_owner(domain, account);
        // 2. check domain expiration
        let hashed_root_domain = self.hash_domain(domain.slice(domain.len() - 1, 1));
        let root_domain_data = self._domain_data.read(hashed_root_domain);
        assert(get_block_timestamp() <= root_domain_data.expiry, 'this domain has expired');
    }

    fn assert_is_owner(
        self: @Naming::ContractState, domain: Span<felt252>, account: ContractAddress
    ) -> u32 {
        let hashed_domain = self.hash_domain(domain);
        let data = self._domain_data.read(hashed_domain);

        // because erc721 crashes on zero
        let owner = if data.owner == 0 {
            ContractAddressZeroable::zero()
        } else {
            IIdentityDispatcher { contract_address: self.starknetid_contract.read() }
                .owner_of(data.owner)
        };

        // if caller owns the starknet id, he owns the domain, we return the key
        if owner == account {
            return data.key;
        };

        // otherwise, if it is a root domain, he doesn't own it
        assert(domain.len() != 1 && domain.len() != 0, 'you don\'t own this domain');

        // if he doesn't own the starknet id, and doesn't own the domain, he might own the parent domain
        let parent_key = self.assert_is_owner(domain.slice(1, domain.len() - 1), account);
        // we ensure that the key is the same as the parent key
        // this is to allow to revoke all subdomains in o(1) writes, by juste updating the key of the parent
        if (data.parent_key != 0) {
            assert(parent_key == data.parent_key, 'you no longer own this domain');
        };
        data.key
    }

    // this ensures a non expired domain is not already written on this identity
    fn assert_id_availability(self: @Naming::ContractState, identity: u128, timestamp: u64) {
        let id_hashed_domain = IIdentityDispatcher {
            contract_address: self.starknetid_contract.read()
        }
            .get_verifier_data(identity, 'name', get_contract_address(), 0);
        assert(
            id_hashed_domain == 0 || self._domain_data.read(id_hashed_domain).expiry < timestamp,
            'this id holds a domain'
        );
    }
}
