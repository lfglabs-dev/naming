use starknet::{ContractAddress, ClassHash};
use naming::naming::main::Naming::Discount;

#[starknet::interface]
trait INaming<TContractState> {
    // view
    fn resolve(self: @TContractState, domain: Span<felt252>, field: felt252) -> felt252;

    fn domain_to_id(self: @TContractState, domain: Span<felt252>) -> u128;

    fn domain_to_address(self: @TContractState, domain: Span<felt252>) -> ContractAddress;

    fn address_to_domain(self: @TContractState, address: ContractAddress) -> Array<felt252>;

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

    fn transfer_domain(ref self: TContractState, domain: Span<felt252>, target_id: u128);

    // admin
    fn set_admin(ref self: TContractState, new_admin: ContractAddress);

    fn claim_balance(ref self: TContractState, erc20: ContractAddress);

    fn set_discount(ref self: TContractState, discount_id: felt252, discount: Discount);

    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
