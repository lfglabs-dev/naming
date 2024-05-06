use starknet::ContractAddress;

#[starknet::interface]
trait IAutoRenewal<TContractState> {
    fn get_renewing_allowance(
        self: @TContractState, domain: felt252, renewer: starknet::ContractAddress,
    ) -> u256;

    // naming, erc20, tax
    fn get_contracts(
        self: @TContractState
    ) -> (starknet::ContractAddress, starknet::ContractAddress, starknet::ContractAddress);
}
