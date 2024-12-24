use starknet::{ContractAddress, get_tx_info};
// use core::pedersen::PedersenTrait;
// use core::hash::{HashStateTrait, HashStateExTrait};
use starknet::get_caller_address;

#[starknet::interface]
trait IPointManager<TContractState> {
    // EXTERNAL FUNCTIONS
    fn process_level(ref self: TContractState, user: ContractAddress, level: u32, has_won: bool);
    fn reward_mission(ref self: TContractState, user: ContractAddress, reward_points: u32);
    fn buy_lives(ref self: TContractState, amount: u32);

    // SETTER
    fn set_currency(ref self: TContractState, address: ContractAddress);
    fn set_life_pack_price(ref self: TContractState, amount: u32, price: u256);
    fn set_max_life(ref self: TContractState, max_life: u32);
    fn set_point_per_level(ref self: TContractState, point: u32);
    fn set_time_per_life(ref self: TContractState, time: u64);
    fn set_permission(ref self: TContractState, address: ContractAddress, permission: bool);

    // GETTER
    fn get_token_address(self: @TContractState) -> ContractAddress;
    fn get_life_pack_price(self: @TContractState, amount: u32) -> u256;
    fn get_max_life(self: @TContractState) -> u32;
    fn get_point_per_level(self: @TContractState) -> u32;
    fn get_time_per_life(self: @TContractState) -> u64;

    // OTHER GETTER
    fn get_life(self: @TContractState, address: ContractAddress) -> u32;
    fn get_time_recover_free_life(self: @TContractState, address: ContractAddress) -> u64;
    fn get_user_point(self: @TContractState, address: ContractAddress) -> u32;
    fn get_user_level(self: @TContractState, address: ContractAddress, level: u32) -> bool;
    fn get_owner(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod PointManager {
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

    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    const STARKNET_DOMAIN_TYPE_HASH: felt252 =
        selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");

    const SIMPLE_STRUCT_TYPE_HASH: felt252 =
        selector!("Ticket(address:ContractAddress,amount:u256,timestamp:u256)");

    #[storage]
    struct Storage {
        owner: ContractAddress,
        admin: ContractAddress,
        currency: ContractAddress,
        max_life: u32,
        point_per_level: u32,
        time_per_life: u64,
        life_pack_price: LegacyMap::<u32, u256>,
        user_level: LegacyMap::<(ContractAddress, u32), bool>,
        user_point: LegacyMap::<ContractAddress, u32>,
        user_life: LegacyMap::<ContractAddress, u32>,
        user_free_life: LegacyMap::<ContractAddress, u64>,
        whitelisted_contract: LegacyMap::<ContractAddress, bool>,
        used_proof: LegacyMap::<felt252, bool>,
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
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        currency: ContractAddress,
        max_life: u32,
        point_per_level: u32,
        time_per_life: u64
    ) {
        self.owner.write(owner);
        self.admin.write(owner);
        self.currency.write(currency);
        self.max_life.write(max_life);
        self.point_per_level.write(point_per_level);
        self.time_per_life.write(time_per_life);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        // External events
        LevelWon: LevelWon,
        LevelLost: LevelLost,
        MissionRewarded: MissionRewarded,
        LivesUpdated: LivesUpdated,
        FreeLivesUpdated: FreeLivesUpdated,
        PointsUpdated: PointsUpdated,
        
        // Setter events
        CurrencyUpdated: CurrencyUpdated,
        LifePackPriceUpdated: LifePackPriceUpdated,
        MaxLifeUpdated: MaxLifeUpdated,
        PointPerLevelUpdated: PointPerLevelUpdated,
        TimePerLifeUpdated: TimePerLifeUpdated,
        PermissionUpdated: PermissionUpdated,

        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct LevelWon {
        user: ContractAddress,
        level: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct LevelLost {
        user: ContractAddress,
        level: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct MissionRewarded {
        user: ContractAddress,
        points: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct LivesUpdated {
        user: ContractAddress,
        lives: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct FreeLivesUpdated {
        user: ContractAddress,
        lives: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PointsUpdated {
        user: ContractAddress,
        points: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct CurrencyUpdated {
        new_currency: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct LifePackPriceUpdated {
        amount: u32,
        new_price: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MaxLifeUpdated {
        new_max_life: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct PointPerLevelUpdated {
        new_point: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct TimePerLifeUpdated {
        new_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PermissionUpdated {
        address: ContractAddress,
        permission: bool,
    }


    #[abi(embed_v0)]
    impl PointManager of super::IPointManager<ContractState> {
        // EXTERNAL FUNCTIONS
        fn process_level(
            ref self: ContractState, user: ContractAddress, level: u32, has_won: bool,
        ) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.reentrancy.start();

            if (has_won) {
                let mut current_points = self.user_point.read(user);
                let new_points = current_points + self.point_per_level.read();

                self.user_point.write(user, new_points);
                self.user_level.write((user, level), true);

                self.emit(LevelWon { user, level });
                self.emit(PointsUpdated { user, points: new_points });
            } else {
                self.emit(LevelLost { user, level });
            }

            let now = get_block_timestamp();
            let time_per_life = self.time_per_life.read();
            let user_free_life = self.user_free_life.read(user);
            let max_life = self.max_life.read().into();
            let mut count_life = (now - user_free_life) / time_per_life;

            if (count_life >= max_life) {
                count_life = max_life;
                if (!has_won) {
                    count_life -= 1
                }
                self.user_free_life.write(user, now - (count_life * time_per_life));
                self.emit(FreeLivesUpdated { user, lives: count_life * time_per_life });
            } else if (count_life >= 1) {
                let mut time = user_free_life;
                if (!has_won) {
                    time += time_per_life;
                    self.user_free_life.write(user, time);
                }
                self.emit(FreeLivesUpdated { user, lives: time - user_free_life });
            } else if (count_life == 0) {
                let mut life = self.user_life.read(user);
                assert(life >= 1, 'No lives left');
                if (!has_won) {
                    self.user_life.write(user, life - 1);
                }
                self.emit(LivesUpdated { user, lives: life - 1 });
            }

            self.reentrancy.end();
        }

        fn reward_mission(ref self: ContractState, user: ContractAddress, reward_points: u32,) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.reentrancy.start();

            let current_points = self.user_point.read(user);
            let new_points = current_points + reward_points;
            self.user_point.write(user, new_points);

            self.emit(MissionRewarded { user, points: reward_points });
            self.emit(PointsUpdated { user, points: new_points });

            self.reentrancy.end();
        }

        fn buy_lives(ref self: ContractState, amount: u32) {
            let caller_address = get_caller_address();
            self.reentrancy.start();

            let mut current_lives = self.user_life.read(caller_address);
            let currency_erc20 = IERC20CamelDispatcher { contract_address: self.currency.read() };
            let balance = currency_erc20.balanceOf(caller_address);
            let price = self.life_pack_price.read(amount);

            assert(price != 0, 'Pack is not available');
            assert(balance >= price, 'Insufficient balance');

            currency_erc20.transferFrom(caller_address, self.owner.read(), price);
            let new_lives = current_lives + amount;
            self.user_life.write(caller_address, current_lives);

            self.emit(LivesUpdated { user: caller_address, lives: new_lives });
            self.reentrancy.end();
        }

        // SETTER

        fn set_currency(ref self: ContractState, address: ContractAddress) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.currency.write(address);
            self.emit(CurrencyUpdated { new_currency: address });
        }

        fn set_life_pack_price(ref self: ContractState, amount: u32, price: u256) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.life_pack_price.write(amount, price);
            self.emit(LifePackPriceUpdated { amount, new_price: price });
        }

        fn set_max_life(ref self: ContractState, max_life: u32) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.max_life.write(max_life);
            self.emit(MaxLifeUpdated { new_max_life: max_life });
        }

        fn set_point_per_level(ref self: ContractState, point: u32) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.point_per_level.write(point);
            self.emit(PointPerLevelUpdated { new_point: point });
        }

        fn set_time_per_life(ref self: ContractState, time: u64) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.time_per_life.write(time);
            self.emit(TimePerLifeUpdated { new_time: time });
        }

        fn set_permission(ref self: ContractState, address: ContractAddress, permission: bool) {
            assert(self.owner.read() == get_caller_address(), 'Caller not owner');
            self.whitelisted_contract.write(address, permission);
            self.emit(PermissionUpdated { address, permission });
        }

        // GETTER

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.currency.read()
        }

        fn get_life_pack_price(self: @ContractState, amount: u32) -> u256 {
            self.life_pack_price.read(amount)
        }

        fn get_max_life(self: @ContractState) -> u32 {
            self.max_life.read()
        }

        fn get_point_per_level(self: @ContractState) -> u32 {
            self.point_per_level.read()
        }

        fn get_time_per_life(self: @ContractState) -> u64 {
            self.time_per_life.read()
        }

        // OTHER GETTER

        fn get_life(self: @ContractState, address: ContractAddress) -> u32 {
            self.user_life.read(address)
        }

        fn get_time_recover_free_life(self: @ContractState, address: ContractAddress) -> u64 {
            self.user_free_life.read(address)
        }

        fn get_user_point(self: @ContractState, address: ContractAddress) -> u32 {
            self.user_point.read(address)
        }

        fn get_user_level(self: @ContractState, address: ContractAddress, level: u32) -> bool {
            self.user_level.read((address, level))
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
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
                name: 'RexBlitz_PointManager', version: 1, chain_id: get_tx_info().unbox().chain_id
            };
            let mut state = PedersenTrait::new(0);
            state = state.update_with('StarkNet Message');
            state = state.update_with(domain.hash_struct());
            state = state.update_with(signer);
            let ticket = Ticket { address: get_caller_address(), timestamp: timestamp };
            state = state.update_with(ticket.hash_struct());
            // Hashing with the amount of elements being hashed 
            state = state.update_with(4);
            state.finalize()
        }
    }
}
