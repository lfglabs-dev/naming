use starknet::{ContractAddress, ClassHash};
use naming::naming::main::Naming::{Discount, DomainData};

#[starknet::interface]
trait INaming<TContractState> {
    // view
    fn resolve(
        self: @TContractState, domain: Span<felt252>, field: felt252, hint: Span<felt252>
    ) -> felt252;

    fn domain_to_data(self: @TContractState, domain: Span<felt252>) -> DomainData;

    fn domain_to_expiry(self: @TContractState, domain: Span<felt252>) -> u64;

    fn domain_to_id(self: @TContractState, domain: Span<felt252>) -> u128;

    fn domain_to_address(
        self: @TContractState, domain: Span<felt252>, hint: Span<felt252>
    ) -> ContractAddress;

    fn address_to_domain(self: @TContractState, address: ContractAddress) -> Span<felt252>;

    // external
    fn buy(
        ref self: TContractState,
        id: u128,
        domain: felt252,
        days: u16,
        resolver: ContractAddress,
        sponsor: ContractAddress,
        discount_id: felt252,
        metadata: felt252,
    );

    fn altcoin_buy(
        ref self: TContractState,
        id: u128,
        domain: felt252,
        days: u16,
        resolver: ContractAddress,
        sponsor: ContractAddress,
        discount_id: felt252,
        metadata: felt252,
        altcoin_addr: ContractAddress,
        quote: u128,
        max_validity: u64,
        sig: (felt252, felt252),
    );

    fn renew(
        ref self: TContractState,
        domain: felt252,
        days: u16,
        sponsor: ContractAddress,
        discount_id: felt252,
        metadata: felt252,
    );

    fn altcoin_renew(
        ref self: TContractState,
        domain: felt252,
        days: u16,
        sponsor: ContractAddress,
        discount_id: felt252,
        metadata: felt252,
        altcoin_addr: ContractAddress,
        quote: u128,
        max_validity: u64,
        sig: (felt252, felt252),
    );

    fn altcoin_renew_subscription(
        ref self: TContractState,
        domain: felt252,
        days: u16,
        sponsor: ContractAddress,
        discount_id: felt252,
        metadata: felt252,
        altcoin_addr: ContractAddress,
        price_in_altcoin: u256,
    );

    fn transfer_domain(ref self: TContractState, domain: Span<felt252>, target_id: u128);

    fn reset_subdomains(ref self: TContractState, domain: Span<felt252>);

    fn set_address_to_domain(ref self: TContractState, domain: Span<felt252>);

    fn clear_legacy_domain_to_address(ref self: TContractState, domain: Span<felt252>);

    fn reset_address_to_domain(ref self: TContractState);

    fn migrate_domain(ref self: TContractState, domain: Span<felt252>);

    fn set_domain_to_resolver(
        ref self: TContractState, domain: Span<felt252>, resolver: ContractAddress
    );

    // admin
    fn set_admin(ref self: TContractState, new_admin: ContractAddress);

    fn set_expiry(ref self: TContractState, root_domain: felt252, expiry: u64, metadata: felt252);

    fn claim_balance(ref self: TContractState, erc20: ContractAddress);

    fn set_discount(ref self: TContractState, discount_id: felt252, discount: Discount);

    fn set_pricing_contract(ref self: TContractState, pricing_contract: ContractAddress);

    fn set_referral_contract(ref self: TContractState, referral_contract: ContractAddress);

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    fn set_server_pub_key(ref self: TContractState, new_key: felt252);

    fn whitelist_renewal_contract(ref self: TContractState, contract: ContractAddress);

    fn blacklist_renewal_contract(ref self: TContractState, contract: ContractAddress);
}
