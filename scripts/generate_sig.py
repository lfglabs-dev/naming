#!/usr/bin/env python3
from starkware.crypto.signature.signature import private_to_stark_key, get_random_private_key, sign
from starknet_py.hash.utils import pedersen_hash

priv_key = 123
pub_key = private_to_stark_key(priv_key)
print("pub_key:", hex(pub_key))

user_addr = 0x123
erc20_addr = 0x5
quote = 1221805004292776
max_validity = 1000
encoded_string = 724720344857006587549020016926517802128122613457935427138661
data = pedersen_hash(pedersen_hash(pedersen_hash(pedersen_hash(user_addr, erc20_addr), quote), max_validity), encoded_string)

(x, y) = sign(data, priv_key)
print("sig:", hex(x), hex(y))