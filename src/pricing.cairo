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
    fn constructor(ref self: ContractState, erc20_address: ContractAddress, ) {
        self.erc20.write(erc20_address);
    }

    #[external(v0)]
    impl PricingImpl of IPricing<ContractState> {
        fn compute_buy_price(
            self: @ContractState, domain: felt252, days: u16
        ) -> (ContractAddress, u256) {
            (self.erc20.read(), u256 { low: self.get_price_per_day(domain) * days.into(), high: 0 })
        }

        fn compute_renew_price(
            self: @ContractState, domain: felt252, days: u16
        ) -> (ContractAddress, u256) {
            (self.erc20.read(), u256 { low: self.get_price_per_day(domain) * days.into(), high: 0 })
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_amount_of_chars(self: @ContractState, domain: u256) -> u128 {
            if domain == (u256 { low: 0, high: 0 }) {
                return 0;
            }
            // 38 = simple_alphabet_size
            let (p, q, _) = u256_safe_divmod(domain, u256_as_non_zero(u256 { low: 38, high: 0 }));
            if q == (u256 { low: 37, high: 0 }) {
                // 3 = complex_alphabet_size
                let (shifted_p, _, _) = u256_safe_divmod(
                    p, u256_as_non_zero(u256 { low: 2, high: 0 })
                );
                let next = self.get_amount_of_chars(shifted_p);
                return 1 + next;
            }
            let next = self.get_amount_of_chars(p);
            1 + next
        }

        fn get_price_per_day(self: @ContractState, domain: felt252) -> u128 {
            let number_of_character = self.get_amount_of_chars(domain.into());

            if number_of_character == 1 {
                return 1068493150684932;
            }

            if number_of_character == 2 {
                return 657534246575343;
            }

            if number_of_character == 3 {
                return 410958904109590;
            }

            if number_of_character == 4 {
                return 232876712328767;
            }

            return 24657534246575;
        }
    }
}
