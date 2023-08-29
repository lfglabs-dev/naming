use starknet::ContractAddress;


#[derive(Drop, starknet::Event)]
struct DomainMint {
    #[key]
    domain: felt252,
    owner: u128,
    expiry: u64
}

#[derive(Drop, starknet::Event)]
struct DomainRenewal {
    #[key]
    domain: felt252,
    new_expiry: u64,
}

#[derive(Drop, starknet::Event)]
struct DomainToResolver {
    #[key]
    domain: Span<felt252>,
    resolver: ContractAddress
}

#[derive(Drop, starknet::Event)]
struct DomainTransfer {
    #[key]
    domain: Span<felt252>,
    prev_owner: u128,
    new_owner: u128
}

#[derive(Drop, starknet::Event)]
struct SaleMetadata {
    domain: felt252,
    metadata: felt252
}
