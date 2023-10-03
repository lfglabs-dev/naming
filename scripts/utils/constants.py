import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.net.models.chains import StarknetChainId

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
load_dotenv()

NETWORKS = {
    "mainnet": {
        "name": "mainnet",
        "explorer_url": "https://voyager.online",
        "feeder_gateway_url": "https://alpha-mainnet.starknet.io/feeder_gateway",
        "gateway_url": "https://alpha-mainnet.starknet.io/gateway",
    },
    "testnet": {
        "name": "testnet",
        "explorer_url": "https://goerli.voyager.online",
        "feeder_gateway_url": "https://alpha4.starknet.io/feeder_gateway",
        "gateway_url": "https://alpha4.starknet.io/gateway",
    },
    "devnet": {
        "name": "devnet",
        "explorer_url": "",
        "rpc_url": "http://127.0.0.1:5050/rpc",
        "feeder_gateway_url": "http://localhost:5050/feeder_gateway",
        "gateway_url": "http://localhost:5050/gateway",
    },
}

VARS = NETWORKS[os.getenv("STARKNET_NETWORK", "devnet")]
VARS["account_address"] = os.environ.get(f"{VARS['name'].upper()}_ACCOUNT_ADDRESS")
if VARS["account_address"] is None:
    logger.warning(
        f"⚠️ {VARS['name'].upper()}_ACCOUNT_ADDRESS not set, defaulting to ACCOUNT_ADDRESS"
    )
    VARS["account_address"] = os.getenv("ACCOUNT_ADDRESS")
VARS["private_key"] = os.environ.get(f"{VARS['name'].upper()}_PRIVATE_KEY")
if VARS["private_key"] is None:
    logger.warning(
        f"⚠️  {VARS['name'].upper()}_PRIVATE_KEY not set, defaulting to PRIVATE_KEY"
    )
    VARS["private_key"] = os.getenv("PRIVATE_KEY")
if VARS["name"] == "mainnet":
    VARS["rpc_url"] = os.getenv("MAINNET_RPC_URL")
    VARS["chain_id"] = StarknetChainId.MAINNET
elif VARS["name"] == "testnet2":
    VARS["rpc_url"] = os.getenv("TESTNET2_RPC_URL")
    VARS["chain_id"] = StarknetChainId.TESTNET2
elif VARS["name"] != "devnet":
    VARS["rpc_url"] = os.getenv("TESTNET_RPC_URL")
    VARS["chain_id"] = StarknetChainId.TESTNET

FULL_NODE_CLIENT = FullNodeClient(
    node_url=VARS["rpc_url"],
    net=VARS["feeder_gateway_url"],
)

ETH_TOKEN_ADDRESS = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7
ETH_CLASS_HASH = 0x6A22BF63C7BC07EFFA39A25DFBD21523D211DB0100A0AFD054D172B81840EAF
SOURCE_DIR = Path("src")
CONTRACTS = {p.stem: p for p in list(SOURCE_DIR.glob("**/*.cairo"))}

BUILD_DIR = Path("target/release")
BUILD_DIR.mkdir(exist_ok=True, parents=True)
DEPLOYMENTS_DIR = Path("deployments") / VARS["name"]
DEPLOYMENTS_DIR.mkdir(exist_ok=True, parents=True)

COMPILED_CONTRACTS = [
    {"contract_name": "naming_Identity", "is_account_contract": False},
    {"contract_name": "naming_Pricing", "is_account_contract": False},
    {"contract_name": "naming_Naming", "is_account_contract": False},
]
