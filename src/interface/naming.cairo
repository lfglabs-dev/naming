use starknet::ContractAddress;

#[starknet::interface]
trait INaming<TContractState> {
    fn resolve(self: @TContractState, domain: felt252, field: felt252) -> felt252;
}
