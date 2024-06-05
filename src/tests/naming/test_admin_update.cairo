use starknet::testing;
use starknet::ContractAddress;
use starknet::contract_address::ContractAddressZeroable;
use starknet::contract_address_const;
use starknet::testing::set_contract_address;
use super::super::utils;
use super::common::deploy;
use naming::naming::main::Naming;
use naming::interface::naming::{INamingDispatcher, INamingDispatcherTrait};
use openzeppelin::{
    access::ownable::interface::{IOwnableTwoStep, IOwnableTwoStepDispatcher, IOwnableTwoStepDispatcherTrait},
    token::erc20::{
    interface::{IERC20Camel, IERC20CamelDispatcher, IERC20CamelDispatcherTrait}
}};

#[test]
#[available_gas(2000000000)]
fn test_update_admin() {
    // setup
    let (_, _, _, naming) = deploy();
    let admin = contract_address_const::<0x123>();
    let new_admin = contract_address_const::<0x456>();

    let ownable2Step = IOwnableTwoStepDispatcher { contract_address: naming.contract_address };

    // we call the update_admin function with the new admin
    set_contract_address(admin);
    naming.update_admin(new_admin);
    assert(ownable2Step.owner() == new_admin, 'change of admin failed');

    // Now we go back to the first admin, this time using the ownable2Step
    set_contract_address(new_admin);
    ownable2Step.transfer_ownership(admin);
    set_contract_address(admin);
    ownable2Step.accept_ownership();
    assert(ownable2Step.owner() == admin, 'change of admin failed');
}