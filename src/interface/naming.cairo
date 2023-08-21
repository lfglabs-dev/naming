use starknet::ContractAddress;

#[starknet::interface]
trait INaming<TContractState> {
    fn buy(
        ref self: TContractState,
        id: u128,
        domain: felt252,
        days: u16,
        resolver: ContractAddress,
        sponsor: ContractAddress,
        metadata: felt252,
    );

    fn transfer_domain(ref self: TContractState, domain: Span<felt252>, target_id: u128);

    fn resolve(self: @TContractState, domain: Span<felt252>, field: felt252) -> felt252;

    fn domain_to_id(self: @TContractState, domain: Span<felt252>) -> u128;

    fn domain_to_address(self: @TContractState, domain: Span<felt252>) -> ContractAddress;

    fn address_to_domain(self: @TContractState, address: ContractAddress) -> Array<felt252>;
}
