# %% Imports
import logging
from asyncio import run
from dotenv import load_dotenv
from utils.constants import COMPILED_CONTRACTS, ETH_TOKEN_ADDRESS
from utils.starknet import (
    deploy_v2,
    declare_v2,
    dump_declarations,
    get_starknet_account,
    dump_deployments,
)
import os

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

load_dotenv()
NETWORK = os.getenv("STARKNET_NETWORK")

# https://api.starknet.id/uri?id=
if NETWORK == "mainnet":
    CONST = [0x68747470733A2F2F6170692E737461726B6E65742E69642F7572693F69643D]
# https://goerli.api.starknet.id/uri?id=
elif NETWORK == "goerli":
    CONST = [
        0x68747470733A2F2F676F65726C692E6170692E737461726B6E65742E69642F,
        0x7572693F69643D,
    ]
# https://sepolia.api.starknet.id/uri?id=
elif NETWORK == "sepolia":
    CONST = [
        184555836509371486645449132961545395972629558923458913947591422899062204772,
        3419765288418763837,
    ]


# %% Main
async def main():
    # %% Declarations
    account = await get_starknet_account()
    logger.info("ℹ️  Using account %s as deployer", hex(account.address))

    class_hash = {
        contract["contract_name"]: await declare_v2(contract["contract_name"])
        for contract in COMPILED_CONTRACTS
    }
    dump_declarations(class_hash)

    deployments = {}
    deployments["naming_Identity"] = await deploy_v2(
        "naming_Identity",
        account.address,
        CONST,
    )
    identity_addr = deployments["naming_Identity"]["address"]

    deployments["naming_Pricing"] = await deploy_v2(
        "naming_Pricing",
        ETH_TOKEN_ADDRESS,
    )
    pricing_addr = deployments["naming_Pricing"]["address"]

    deployments["naming_Naming"] = await deploy_v2(
        "naming_Naming",
        identity_addr,
        pricing_addr,
        0,
        account.address,
    )
    dump_deployments(deployments)


# %% Run
if __name__ == "__main__":
    run(main())
