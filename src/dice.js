const { ethers } = require('ethers');
const { contract, provider, walletConnected } = require('./ethers/index.js');
let { gameState, betData, result } = require('./gameStates.js');
let timer = 0;
let seconds = 0;
let flag = true;
let getGameState = true;
let currentRoundId = ethers.formatEther('0');
async function startGame() {
  if (getGameState && gameState === '') {
    try {
      getGameState = false;
      gameState = await contract.gameState();
      currentRoundId = ethers.formatEther(await contract.roundId());
    } catch (error) {
      getGameState = true;
    }
  }
  switch (gameState) {
    case 'START':
      timer = new Date();
      timer.setSeconds(timer.getSeconds() + 60);
      result = {};
      gameState = 'WAIT';
      break;
    case 'WAIT':
      const testtimer = new Date();
      if (timer < testtimer) {
        timer = new Date();
        gameState = 'FINISH';
      }
      // in reverse show seconds left
      seconds = Math.floor((timer - testtimer) / 1000);

      break;
    case 'FINISH':
      // const estimatedGasLimit = await contract.estimateGas.manualfulfill(math.random() % 6); //
      if (flag) {
        console.log('connecting wallet...');
        flag = false;
        const winningSide = Math.floor(Math.random() * 6) + 1;
        // const winningSide = Math.floor(3) + 1;
        const manualGameEndTxUnsigned = await contract.manualGameEnd(
          winningSide
        );
        const approveReceipt = await manualGameEndTxUnsigned.wait();
        console.log('approved', approveReceipt);
        betData = [];
        result.winningSide = winningSide;
        // setInterval(() => {
        gameState = 'RESULT';
        flag = true;
        timer = new Date();
        timer.setSeconds(timer.getSeconds() + 4);
        // }, 3000);
      }
      break;
    case 'RESULT':
      const resTimer = new Date();
      if (timer < resTimer) {
        gameState = 'START';
      }
      seconds = Math.floor((timer - resTimer) / 1000);

      break;
    default:
      break;
  }
  return {
    gameState,
    betData,
    result,
    roundId: currentRoundId,
    seconds,
  };
}

contract.on('BetPlaced', (player, side, amount) => {
  console.log(
    JSON.stringify({
      player,
      side: side.toString(),
      amount: ethers.formatEther(amount),
    })
  );
  betData.push({
    player,
    side: side.toString(),
    amount: ethers.formatEther(amount),
  });
});

contract.on('RoundFinished', (roundId, winningSide, winners) => {
  console.log(
    'Round Finished: ',
    JSON.stringify({
      roundId: ethers.formatEther((roundId * 10) ^ 18),
      winningSide,
      winners,
    })
  );
  currentRoundId = ethers.formatEther(roundId); //roundId;
  result = { winningSide };
});

module.exports = {
  startGame,
};
