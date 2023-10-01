use starknet::ContractAddress;

#[starknet::interface]
trait IReferral<TContractState> {
    fn add_commission(
        self: @TContractState,
        amount: u256,
        sponsor_addr: ContractAddress,
        sponsored_addr: ContractAddress
    );
}
