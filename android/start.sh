#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    pkg install wget -y
fi

if [ ! -f "servidor.zip" ]; then
    echo "Descargando servidor.zip..."
    wget https://raw.githubusercontent.com/UserZero075/DownFast/main/android/servidor.zip
    unzip servidor.zip
fi

cd servidor_\(Termux\)/

if ! command -v node &> /dev/null; then
    echo "Node.js no está instalado. Instalando..."
    pkg install nodejs -y
fi

termux-setup-storage
echo -e "\033[32mServidor interno de la App habilitado\033[0m"
node index.js
