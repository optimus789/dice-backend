// Import ethers library
const ethers = require('ethers');
const { gameState } = require('../gameStates');

// Define Sepolia testnet settings
// const sepolia = {
//     name: 'sepolia',
//     chainId: 11155111,
//     _defaultProvider: (providers) => new providers.JsonRpcProvider('https://rpc.sepolia.org')
// };

// const mnemonic = 'uniform genre already educate indoor loop toast primary region they speak open'; // Replace with
const privateKey = process.env.PRIVATE_KEY;

// const provider1 = ethers.getDefaultProvider('homestead'); // e.g., 'homestead' for Mainnet, 'rinkeby' for Rinkeby Testnet
const provider = new ethers.JsonRpcProvider(
  'https://replicator.pegasus.lightlink.io/rpc/v1'
);
const signer = new ethers.Wallet(privateKey, provider);

const walletConnected = signer.connect(provider);

// Connect to Sepolia testnet

const contractABI = [
  {
    inputs: [
      {
        internalType: 'address',
        name: '_DICEAddress',
        type: 'address',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'player',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'side',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    name: 'BetPlaced',
    type: 'event',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'numberSide',
        type: 'uint256',
      },
    ],
    name: 'manualGameEnd',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: '_side',
        type: 'uint256',
      },
      {
        internalType: 'uint256',
        name: '_amount',
        type: 'uint256',
      },
    ],
    name: 'placeBet',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'roundId',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'winningSide',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'address[]',
        name: 'winners',
        type: 'address[]',
      },
    ],
    name: 'RoundFinished',
    type: 'event',
  },
  {
    inputs: [],
    name: 'startWait',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: '',
        type: 'address',
      },
    ],
    name: 'bets',
    outputs: [
      {
        internalType: 'uint256',
        name: 'side',
        type: 'uint256',
      },
      {
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'DICE',
    outputs: [
      {
        internalType: 'contract IDiceToken',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'gameState',
    outputs: [
      {
        internalType: 'string',
        name: '',
        type: 'string',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'managerAddress',
    outputs: [
      {
        internalType: 'address',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'roundId',
    outputs: [
      {
        internalType: 'uint256',
        name: '',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
];

// The address of the deployed contract
const contractAddress = '0x4dCd09E2D6369aC473E59DeD597014944e12Bd27';

// Creating a contract instance
const contract = new ethers.Contract(contractAddress, contractABI, signer);

// Example of reading data from the contract
async function readContractData() {
  try {
    console.log('TESTING', walletConnected.address);
    console.log('signer', signer);
    let balance = await provider.getBalance(walletConnected.address);
    // const gameState = await contract.gameState();
    console.log('Data from contract:', balance);
  } catch (error) {
    console.error('Error:', error);
  }
}

module.exports = {
  provider,
  // readContractData,
  contract,
  walletConnected,
  signer,
};
