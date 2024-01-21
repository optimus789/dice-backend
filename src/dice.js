
const { ethers } = require('ethers');
const { contract, provider, walletConnected } = require('./ethers/index.js');
let { gameState, betData, result } = require('./gameStates.js');
let timer = 0;
let flag = true;
let getGameState = true;
let currentRoundId = ethers.formatEther('0');
async function startGame() {
    if (getGameState && gameState === '') {
        try {
            getGameState = false;
            gameState = await contract.gameState();
            currentRoundId = ethers.formatEther(await contract.roundId())
        } catch (error) {
            getGameState = true
        }
    }
    switch (gameState) {
        case 'START':
            timer = new Date();
            timer.setSeconds(timer.getSeconds() + 30);
            gameState = 'WAIT';
            break;
        case 'WAIT':
            const testtimer = new Date();
            if (timer < testtimer) {
                timer = new Date();
                timer.setSeconds(timer.getSeconds() + 30);
                gameState = 'FINISH';
            }
            break;
        case 'FINISH':
            console.log("ENDING GAME");
            // const estimatedGasLimit = await contract.estimateGas.manualfulfill(math.random() % 6); // 
            if (flag) {
                console.log("connecting wallet...");
                flag = false;
                const manualfulfillTxUnsigned = await contract.manualfulfill(parseInt(Math.random() % 6));
                // // // manualfulfillTxUnsigned.chainId = 11155111; // chainId 1 for Ethereum mainnet
                // // // manualfulfillTxUnsigned.gasLimit = 100000000//estimatedGasLimit;
                // // // manualfulfillTxUnsigned.gasPrice = await provider.getGasPrice();
                // // // manualfulfillTxUnsigned.nonce = await provider.getTransactionCount(walletConnected.address)
                // // // const manualfulfillTxSigned = await walletConnected.signTransaction(manualfulfillTxUnsigned);
                // // // const submittedTx = await provider.sendTransaction(manualfulfillTxSigned);
                const approveReceipt = await manualfulfillTxUnsigned.wait();
                console.log('approved', approveReceipt);
                flag = true;
                betData = [];
                result = {};
                gameState = 'START';
            }
            break;

        default:
            break;
    }
    return {
        gameState,
        betData,
        result,
        roundId: currentRoundId
    }
}


contract.on('BetPlaced', (player, side, amount) => {
    console.log({ player, side, amount });
    betData.push({ player, side: side.toString(), amount: amount.toString() });
})

contract.on('RoundFinished', (roundId, winningSide, winners) => {
    console.log({ roundId:ethers.formatEther(roundId), winningSide, winners })
    currentRoundId = ethers.formatEther(roundId) //roundId;
    result = { winningSide, winners }
})


module.exports = {
    startGame
}