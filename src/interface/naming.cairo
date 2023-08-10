use starknet::ContractAddress;

#[starknet::interface]
trait INaming<TContractState> {
    fn resolve(self: @TContractState, domain: Array<felt252>, field: felt252) -> felt252;

    fn buy(
        ref self: TContractState,
        id: u128,
        domain: felt252,
        days: u16,
        resolver: ContractAddress,
        sponsor: ContractAddress
    );
}
