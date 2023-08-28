use starknet::ContractAddress;

#[starknet::interface]
trait IPricing<TContractState> {
    fn compute_buy_price(
        self: @TContractState, domain_len: usize, days: u16
    ) -> (ContractAddress, u256);

    fn compute_renew_price(
        self: @TContractState, domain_len: usize, days: u16
    ) -> (ContractAddress, u256);
}
