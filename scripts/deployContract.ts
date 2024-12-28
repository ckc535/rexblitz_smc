import {
    Account,
    hash,
    Contract,
    json,
    Calldata,
    CallData,
    RpcProvider,
    shortString,
    eth,
    uint256,
    byteArray,
    stark,
  } from 'starknet';
  const fs = require('fs');
  
  const RPC = 'https://starknet-mainnet.public.blastapi.io/rpc/v0_7';
  // const RPC = 'https://free-rpc.nethermind.io/sepolia-juno/v0_7';
  const provider = new RpcProvider({ nodeUrl: RPC });
  
  const PRIVATE_KEY = '';
  const ACCOUNT_ADDRESS = '';
  
  const TOKEN_ADDRESS =
    '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d'; //ETH
  
  const account = new Account(provider, ACCOUNT_ADDRESS, PRIVATE_KEY);
  
  // const MAINNET_ADDRESS = '';
  // const MAINNET_PK = '';
  // const mainnetAcc = new Account(provider, MAINNET_ADDRESS, MAINNET_PK);
  
  const DEV_ADDRESS = '0x0759ba5609769874CAB59869f95E6367dE5F03EA1Df6A2D82b2116fd5DcD902c';
  const DEV_PK = '0x0392e0724ccd281a4562c0853f59af0fdbbdd1aad4b293522359714135060420';
  const devAcc = new Account(provider, DEV_ADDRESS, DEV_PK);
    
  async function deployPointManager() {
    console.log('🚀 Deploying with Account: ' + devAcc.address);
  
    const compiledContractCasm = json.parse(
      fs
        .readFileSync(
          '../rexblitz_smc/target/dev/pointmanager_PointManager.compiled_contract_class.json'
        )
        .toString('ascii')
    );
    const compiledContractSierra = json.parse(
      fs
        .readFileSync(
          '../rexblitz_smc/target/dev/pointmanager_PointManager.contract_class.json'
        )
        .toString('ascii')
    );
    const contractCallData = new CallData(compiledContractSierra.abi);
    const contractConstructor = contractCallData.compile('constructor', {
      owner: devAcc.address,
      admin: '0x03bdd0c2384b7bc76b791c6a8417413384873332f1e05685d5ce6bf9284a609e',
      currency: TOKEN_ADDRESS,
      max_life: 7,
      point_per_level: 10,
      time_per_life: 3600,
    });
  
    const deployContractResponse = await devAcc.declareAndDeploy({
      contract: compiledContractSierra,
      casm: compiledContractCasm,
      constructorCalldata: contractConstructor,
    });
    console.log(
      '✅ PointManager Deployed: ',
      deployContractResponse.deploy.contract_address
    );
  }

  deployPointManager();