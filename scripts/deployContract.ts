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
  
  const DEV_ADDRESS = '0x07e6a3b217d4Cd8C4d9b07D024E67146431f4d980eD43E80F03a3ffFa8ac16D4';
  const DEV_PK = '0x02de13e951eb87a3c30959861bb8d9ac358763be971b2b678910ef1d91e5c166';
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