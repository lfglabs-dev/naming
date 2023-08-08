use starknet::ContractAddress;

#[starknet::interface]
trait INaming<TContractState> {
    fn resolve(self: @TContractState, domain: Array<felt252>, field: felt252) -> felt252;
}
