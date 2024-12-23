#[test]
fn test_point_manager() {
    let (contract_address, _) = deploy_contract("./src/PointManager.cairo");
    let contract = IPointManagerDispatcher { contract_address };

    assert(contract.get_owner() == 42, 'Owner is not 42');
}