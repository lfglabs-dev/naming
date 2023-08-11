use starknet::ContractAddress;

#[starknet::interface]
trait INaming<TContractState> {
    fn buy(
        ref self: TContractState,
        id: u128,
        domain: felt252,
        days: u16,
        resolver: ContractAddress,
        sponsor: ContractAddress
    );

    fn resolve(self: @TContractState, domain: Span<felt252>, field: felt252) -> felt252;

    fn domain_to_address(self: @TContractState, domain: Span<felt252>) -> ContractAddress;
}
