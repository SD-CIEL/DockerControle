const express = require('express');
const fs = require('fs');
const app = express();

const LOG_PATH = '/log/messages.log';

app.use(express.static('www'));

app.get('/log', (req, res) => {
  fs.readFile(LOG_PATH, 'utf8', (err, data) => {
    if (err) {
      return res.send("Erreur de lecture du fichier log.");
    }
    res.send(`<pre>${data}</pre>`);
  });
});

app.listen(80, () => console.log('Serveur lancé sur le port 80'));
