use core::array::SpanTrait;
use naming::{
    naming::main::{Naming, Naming::{_hash_to_domain, _hash_to_domainContractMemberStateTrait}}
};
use integer::{u256_safe_divmod, u256_as_non_zero};
use wadray::{Wad, WAD_SCALE};

#[generate_trait]
impl UtilsImpl of UtilsTrait {
    fn hash_domain(self: @Naming::ContractState, domain: Span<felt252>) -> felt252 {
        if domain.len() == 0 {
            return 0;
        };
        let new_len = domain.len() - 1;
        let x = *domain[new_len];
        let y = self.hash_domain(domain.slice(0, new_len));
        let hashed_domain = pedersen::pedersen(x, y);
        return hashed_domain;
    }

    fn store_unhashed_domain(
        ref self: Naming::ContractState, mut domain: Span<felt252>, hashed: felt252
    ) {
        loop {
            match domain.pop_back() {
                Option::Some(x) => { self._hash_to_domain.write((hashed, domain.len()), *x); },
                Option::None => { break; }
            }
        };
    }

    fn unhash_domain(self: @Naming::ContractState, domain_hash: felt252) -> Span<felt252> {
        let mut i = 0;
        let mut domain = ArrayTrait::new();
        loop {
            let domain_part = self._hash_to_domain.read((domain_hash, i));
            if domain_part == 0 {
                break;
            };
            domain.append(domain_part);
            i += 1;
        };
        domain.span()
    }

    fn get_chars_len(self: @Naming::ContractState, domain: u256) -> usize {
        if domain == (u256 { low: 0, high: 0 }) {
            return 0;
        };
        // 38 = simple_alphabet_size
        let (p, q, _) = u256_safe_divmod(domain, u256_as_non_zero(u256 { low: 38, high: 0 }));
        if q == (u256 { low: 37, high: 0 }) {
            // 3 = complex_alphabet_size
            let (shifted_p, _, _) = u256_safe_divmod(p, u256_as_non_zero(u256 { low: 2, high: 0 }));
            let next = self.get_chars_len(shifted_p);
            return 1 + next;
        };
        let next = self.get_chars_len(p);
        1 + next
    }

    fn get_altcoin_price(
        self: @Naming::ContractState, altcoin_quote: Wad, domain_price_eth: Wad
    ) -> u256 {
        (domain_price_eth / altcoin_quote).into()
    }
}
