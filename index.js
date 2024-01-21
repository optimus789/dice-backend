const express = require('express');
const app = express();
const port = 3001;
const server = require('http').createServer(app);
const cors = require('cors')
const WebSocket = require('ws');
require('dotenv').config();

const wss = new WebSocket.Server({ server: server });

const corsOptions = {
    origin: '*',
    method: ['*'],
    allowedHeaders: ['*'],
    maxAge: 86400
}
app.use(cors(corsOptions))
// app.get('/', (req, res) => {
//     setInterval(async () => {
//         await startGame();
//     }, 500);
//     // provider
//     return res.send('Hello World!')
// });



// app.listen(port, () => console.log(`Example app listening on port ${port}!`));

server.listen(port, () => {
    console.log(`Example app listening on port ${port}!`)
})


module.exports = {
    wss,
}
require('./src/socket');