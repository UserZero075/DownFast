#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update -y && apt install -y wget && apt upgrade -y && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh -y && bash InstallTools.sh -y
fi

if [ ! -f "servidor_v0.5.0.zip" ]; then
    echo "Descargando servidor.zip..."
    wget https://raw.githubusercontent.com/UserZero075/DownFast/main/android/servidor_v0.5.0.zip
    unzip -o servidor_v0.5.0.zip -d servidor_v0.5.0
fi

cd servidor_v0.5.0/servidor_\(Termux\)/

if ! command -v node &> /dev/null; then
    echo "Node.js no está instalado. Instalando..."
    pkg install nodejs -y
fi

termux-setup-storage -y
echo -e "\033[32mServidor interno de la App actualizado!\033[0m"
node index.js
