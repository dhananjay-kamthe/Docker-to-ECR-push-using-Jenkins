const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => res.json({ message: 'Hello from Dockerized app!1' }));

app.listen(port, () => console.log(`Running on port ${port}`));
