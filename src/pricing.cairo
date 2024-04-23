#[starknet::contract]
mod Pricing {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use traits::Into;
    use array::{ArrayTrait};
    use zeroable::Zeroable;
    use starknet::class_hash::ClassHash;
    use naming::interface::pricing::{IPricing, IPricingDispatcher, IPricingDispatcherTrait};
    use integer::{u256_safe_divmod, u256_as_non_zero};

    #[storage]
    struct Storage {
        erc20: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, erc20_address: ContractAddress,) {
        self.erc20.write(erc20_address);
    }

    #[abi(embed_v0)]
    impl PricingImpl of IPricing<ContractState> {
        fn compute_buy_price(
            self: @ContractState, domain_len: usize, days: u16
        ) -> (ContractAddress, u256) {
            (
                self.erc20.read(),
                u256 { low: self.get_price_per_day(domain_len) * days.into(), high: 0 }
            )
        }

        fn compute_renew_price(
            self: @ContractState, domain_len: usize, days: u16
        ) -> (ContractAddress, u256) {
            (
                self.erc20.read(),
                u256 { low: self.get_price_per_day(domain_len) * days.into(), high: 0 }
            )
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_price_per_day(self: @ContractState, domain_len: usize) -> u128 {
            if domain_len == 1 {
                return 1068493150684932;
            }

            if domain_len == 2 {
                return 657534246575343;
            }

            if domain_len == 3 {
                return 200000000000000;
            }

            if domain_len == 4 {
                return 73972602739726;
            }

            return 24657534246575;
        }
    }
}
