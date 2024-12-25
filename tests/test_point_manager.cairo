use core::array::ArrayTrait;
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, start_warp, stop_warp, ContractClass   };
use pointmanager::interfaces::IPointManager::{IPointManagerDispatcher, IPointManagerDispatcherTrait};

use starknet::{ContractAddress,SyscallResultTrait, get_block_timestamp};
use openzeppelin::presets::{account::Account, erc20::ERC20};

const NAME: felt252 = 'Test';
const SYMBOL: felt252 = 'TET';
const DECIMALS: u8 = 18_u8;

fn deploy_account(account_class: ContractClass, name: felt252) -> ContractAddress {
    let mut constructor_calldata: Array<felt252> = array![name];
    let (contract_address, _) = account_class.deploy(@constructor_calldata).unwrap_syscall();
    contract_address
}

fn deploy_erc20(
    erc20_hash: ContractClass,
    name: felt252,
    symbol: felt252,
    decimals: u8,
    total_supply: u256,
    recipent: ContractAddress
) -> ContractAddress {
    let mut constructor_calldata: Array<felt252> = array![name,symbol,decimals.into(),total_supply.try_into().unwrap(),recipent.try_into().unwrap()];
    let (contract_address, _) = erc20_hash.deploy(@constructor_calldata).unwrap_syscall();
    contract_address
}

fn set_up() ->(
    // IPointManagerDispatcher,  
    // ContractAddress,
    ContractAddress,
    ContractAddress) {

        // Declare and deploy the account contracts
        let account_class = declare("Account").unwrap();
        let owner_contract_address = deploy_account(account_class, 'Owner');
        let test_user_contract_addres = deploy_account(account_class, 'Alex');

        // Declare and deploy the ERC20 contract mock
        // let token_contract = declare("ERC20").unwrap();
        // let mut token_calldata = array![NAME,SYMBOL,DECIMALS.into(),1000000000000000000000,owner_contract_address.try_into().unwrap()];
        // let token_address= deploy_erc20(token_contract, NAME, SYMBOL, DECIMALS, 1000000000000000000000, owner_contract_address);
        // let token_dispatcher = IERC20Dispatcher { contract_address: token_address} ;

        // Declare and deploy the FlexStakingPool contract
        // let contract = declare("PointManager").unwrap();
        // let mut constructor_calldata = array![owner_contract_address.try_into().unwrap(),test_user_contract_addres.try_into().unwrap(),10,10,3600];
        // let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap_syscall();
        // let dispatcher = IPointManagerDispatcher { contract_address };

        (
            // dispatcher,
            // contract_address,
            owner_contract_address,
            test_user_contract_addres,
         )
}

#[test]
fn test_setup() {
    // let ( owner, tester) = set_up();
    assert( 1 == 2, 'Owner tester are not the same');
    // let balance = token_dispatcher.balanceOf(owner);


    // assert(balance == 0, 'Owner is not 42');
}