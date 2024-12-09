use starknet::{ContractAddress, get_tx_info};
use core::pedersen::PedersenTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use starknet::get_caller_address;


#[starknet::interface]
trait IPoolPoint<TContractState> {
    fn winLevel(ref self: TContractState, user: ContractAddress, level: u32, success: bool);
    fn rewardMission(ref self: TContractState, user: ContractAddress, point: u32);
    fn giveLife(ref self: TContractState, amount: u32);
    fn setTokenAddress(ref self: TContractState, address: ContractAddress);
    fn setLifePackPrice(ref self: TContractState, amount: u32, price: u256);
    fn setTimePerLife(ref self: TContractState, time: u64);
    fn setPointPerLevel(ref self: TContractState, point: u32);
    fn setPermission(ref self: TContractState, address: ContractAddress, permission: bool);
    fn getLife(self: @TContractState, address: ContractAddress) -> u32;
    fn getTimeRecoverFreeLife(self: @TContractState, address: ContractAddress) -> u64;
    fn getPoint(self: @TContractState, address: ContractAddress) -> u32;
    fn getUserLevel(self: @TContractState, address: ContractAddress, level: u32) -> bool;
    fn getTokenAddress(self: @TContractState) -> ContractAddress;
    fn getLifePackPrice(self: @TContractState, amount: u32) -> u256;
    fn getTimePerLife(self: @TContractState) -> u64;
    fn getPointPerLevel(self: @TContractState) -> u32;
    fn getOwner(self: @TContractState) -> ContractAddress;
}


#[starknet::contract]
mod Point {
    use core::traits::Into;
    use core::traits::TryInto;
    use starknet::ContractAddress;
    use starknet::get_tx_info;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use openzeppelin::account::interface::{AccountABIDispatcherTrait, AccountABIDispatcher};
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcherTrait, IERC20CamelDispatcher};


    const STARKNET_DOMAIN_TYPE_HASH: felt252 =
        selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

    const SIMPLE_STRUCT_TYPE_HASH: felt252 =
        selector!("Ticket(address:ContractAddress,amount:u256,timestamp:u256)");

    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);

    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        admin: ContractAddress,
        currency: ContractAddress,
        lifePackPrice: LegacyMap::<u32, u256>,
        timePerLife: u64,
        pointPerLevel: u32,
        userLevel: LegacyMap::<(ContractAddress, u32), bool>,
        userPoint: LegacyMap::<ContractAddress, u32>,
        userLife: LegacyMap::<ContractAddress, u32>,
        userFreeLife: LegacyMap::<ContractAddress, u64>,
        whitelistContract: LegacyMap::<ContractAddress, bool>,
        usedProof: LegacyMap::<felt252, bool>,
        #[substorage(v0)]
        reentrancy: ReentrancyGuardComponent::Storage,
    }
    #[derive(Drop, Copy, Hash)]
    struct Ticket {
        address: ContractAddress,
        timestamp: u256,
    }

    #[derive(Drop, Copy, Hash)]
    struct StarknetDomain {
        name: felt252,
        version: felt252,
        chain_id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, address: ContractAddress, currency: ContractAddress) {
        self.owner.write(address);
        self.admin.write(address);
        self.currency.write(currency);
        self.timePerLife.write(3600);
        self.pointPerLevel.write(100);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
    }


    #[abi(embed_v0)]
    impl PoolPoint of super::IPoolPoint<ContractState> {
        fn winLevel(ref self: ContractState, user: ContractAddress, level: u32, success: bool,) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.reentrancy.start();
            let now = get_block_timestamp();
            let mut count_life = (now - self.userFreeLife.read(user)) / self.timePerLife.read();
            if (count_life >= 7) {
                count_life = 7;
                if (success == false) {
                    count_life -= 1
                }
                self.userFreeLife.write(user, now - (count_life * self.timePerLife.read()));
            } else if (count_life >= 1) {
                let mut time = self.userFreeLife.read(user);
                if (success == false) {
                    time += self.timePerLife.read();
                    self.userFreeLife.write(user, time);
                }
            } else {
                let mut life = self.userLife.read(user);
                assert(life >= 1, 'No life left');
                if (success == false) {
                    life = life - 1;
                    self.userLife.write(user, life);
                }
            }

            if (success == true) {
                let level_status = self.userLevel.read((user, level));
                if (level_status == false) {
                    let mut point = self.userPoint.read(user);
                    point += self.pointPerLevel.read();
                    self.userPoint.write(user, point);
                    self.userLevel.write((user, level), true);
                }
            }
            self.reentrancy.end();
        }

        fn rewardMission(ref self: ContractState, user: ContractAddress, point: u32,) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.reentrancy.start();
            let mut old_point = self.userPoint.read(user);
            old_point += point;
            self.userPoint.write(user, old_point);
            self.reentrancy.end();
        }

        fn giveLife(ref self: ContractState, amount: u32) {
            let callerAddress = get_caller_address();
            let mut sum = self.userLife.read(callerAddress);
            let currency_erc20 = IERC20CamelDispatcher { contract_address: self.currency.read() };
            let balance = currency_erc20.balanceOf(callerAddress);
            let price = self.lifePackPrice.read(amount);
            assert(price != 0, 'Pack is not available!');
            assert(balance >= price, 'Insufficient balance!');
            currency_erc20.transferFrom(callerAddress, self.owner.read(), price);
            sum += amount;
            self.userLife.write(callerAddress, sum);
            self.reentrancy.end();
        }

        fn setTokenAddress(ref self: ContractState, address: ContractAddress) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.currency.write(address);
        }

        fn setLifePackPrice(ref self: ContractState, amount: u32, price: u256) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.lifePackPrice.write(amount, price);
        }

        fn setTimePerLife(ref self: ContractState, time: u64) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.timePerLife.write(time);
        }

        fn setPointPerLevel(ref self: ContractState, point: u32) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.pointPerLevel.write(point);
        }

        fn setPermission(ref self: ContractState, address: ContractAddress, permission: bool) {
            assert(self.owner.read() == get_caller_address(), 'You do not have permission');
            self.whitelistContract.write(address, permission);
        }

        fn getLife(self: @ContractState, address: ContractAddress) -> u32 {
            return self.userLife.read(address);
        }

        fn getTimeRecoverFreeLife(self: @ContractState, address: ContractAddress) -> u64 {
            return self.userFreeLife.read(address);
        }

        fn getPoint(self: @ContractState, address: ContractAddress) -> u32 {
            return self.userPoint.read(address);
        }

        fn getUserLevel(self: @ContractState, address: ContractAddress, level: u32) -> bool {
            return self.userLevel.read((address, level));
        }

        fn getTokenAddress(self: @ContractState) -> ContractAddress {
            return self.currency.read();
        }

        fn getLifePackPrice(self: @ContractState, amount: u32) -> u256 {
            return self.lifePackPrice.read(amount);
        }

        fn getTimePerLife(self: @ContractState) -> u64 {
            return self.timePerLife.read();
        }

        fn getPointPerLevel(self: @ContractState) -> u32 {
            return self.pointPerLevel.read();
        }

        fn getOwner(self: @ContractState) -> ContractAddress {
            return self.owner.read();
        }
    }


    trait IStructHash<T> {
        fn hash_struct(self: @T) -> felt252;
    }

    impl StructHashStarknetDomain of IStructHash<StarknetDomain> {
        fn hash_struct(self: @StarknetDomain) -> felt252 {
            let mut state = PedersenTrait::new(0);
            state = state.update_with(STARKNET_DOMAIN_TYPE_HASH);
            state = state.update_with(*self);
            state = state.update_with(4);
            state.finalize()
        }
    }

    impl StructHashSimpleStruct of IStructHash<Ticket> {
        fn hash_struct(self: @Ticket) -> felt252 {
            let mut state = PedersenTrait::new(0);
            state = state.update_with(SIMPLE_STRUCT_TYPE_HASH);
            state = state.update_with(*self);
            state = state.update_with(4);
            state.finalize()
        }
    }


    #[generate_trait]
    impl ValidateSignature of IValidateSignature {
        fn is_valid_signature(
            self: @ContractState, signer: ContractAddress, hash: felt252, signature: Array<felt252>
        ) -> felt252 {
            let account: AccountABIDispatcher = AccountABIDispatcher { contract_address: signer };
            account.is_valid_signature(hash, signature)
        }

        fn get_message_hash(
            self: @ContractState, timestamp: u256, signer: ContractAddress
        ) -> felt252 {
            let domain = StarknetDomain {
                name: 'poolpoint', version: 1, chain_id: get_tx_info().unbox().chain_id
            };
            let mut state = PedersenTrait::new(0);
            state = state.update_with('StarkNet Message');
            state = state.update_with(domain.hash_struct());
            // This can be a field within the struct, it doesn't have to be get_caller_address().
            state = state.update_with(signer);
            let ticket = Ticket { address: get_caller_address(), timestamp: timestamp };
            state = state.update_with(ticket.hash_struct());
            // Hashing with the amount of elements being hashed 
            state = state.update_with(4);
            state.finalize()
        }
    }
}
