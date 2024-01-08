import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.common import int_from_bytes

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()

FULL_NODE_CLIENT = FullNodeClient(
    node_url=os.getenv("RPC_URL"),
    net=os.getenv("STARKNET_NETWORK"),
)

ACCOUNT_ADDRESS = os.getenv("ACCOUNT_ADDRESS")
PRIVATE_KEY = os.getenv("PRIVATE_KEY")
CHAIN_ID = int_from_bytes(os.getenv("CHAIN_ID").encode("utf-8"))

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
ETH_CLASS_HASH = 0x6A22BF63C7BC07EFFA39A25DFBD21523D211DB0100A0AFD054D172B81840EAF
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

BUILD_DIR = Path("target/release")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
DEPLOYMENTS_DIR = Path("deployments") / os.getenv("STARKNET_NETWORK")
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "naming_Identity", "is_account_contract": False},
    {"contract_name": "naming_Pricing", "is_account_contract": False},
    {"contract_name": "naming_Naming", "is_account_contract": False},
]
