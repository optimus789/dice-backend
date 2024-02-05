// const ws = require('ws');

const { wss } = require("..");
const { startGame } = require("./dice");
const WebSocket = require('ws')
// const wss = new ws.Server({ noServer: true });

// wss.on('connection', function connection(ws) {
//     ws.on('message', function incoming(message) {
//         console.log('received: %s', message);
//     });
//     ws.send('something');
// }
// )

// module.exports = {
//     wss
// }

// wss.on('connection', async (ws) => {
//     try {
//         let data = 'START';
//         setInterval(async () => {
//             startGame().then(val => {
//                 console.log("-------------", val);
//                 data = val;
//             });
//             ws.send(JSON.stringify({ data }));
//         }, 1000);
//     } catch (error) {
//         console.log("ERROR", error);
//     }
// }).on('error', (error) => {
//     console.log("error while connection", error);
// })

wss.broadcast = function broadcast(data) {
    try {

        wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({ data }));
            }
        });
    } catch (error) {
        console.log("ERROR", error, data);
    }
}

let data = 'START';

setInterval(async () => {

    startGame().then(val => {
        console.log("-------------", val);
        data = val;

    });
    wss.broadcast(data)

}, 1000);

// module.exports = {
//     sendData
// }