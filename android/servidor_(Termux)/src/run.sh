#!/bin/bash

wget -O Server_red.zip $1
unzip Server_red.zip
cd proyecto
npm install
sed -i "s/const SERVER_NAME = .*/const SERVER_NAME = '$2';/" server.js
node server.js
