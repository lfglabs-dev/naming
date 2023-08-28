# %% Imports
import logging
from asyncio import run

from utils.constants import COMPILED_CONTRACTS, ETH_TOKEN_ADDRESS
from utils.starknet import (
    deploy_v2,
    declare_v2,
    dump_declarations,
    get_starknet_account,
    dump_deployments,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


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
