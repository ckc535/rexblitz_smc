use starknet::ContractAddress;

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