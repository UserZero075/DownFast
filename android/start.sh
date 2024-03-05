#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update && apt install wget && apt upgrade && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh && bash InstallTools.sh
fi

if [ ! -f "servidor_v0.2.1.zip" ]; then
    echo "Descargando servidor.zip..."
    wget https://raw.githubusercontent.com/UserZero075/DownFast/main/android/servidor_v0.2.1.zip
    unzip -o servidor_v0.2.1.zip -d servidor_v0.2.1
fi

cd servidor_v0.2.1/servidor_\(Termux\)/

if ! command -v node &> /dev/null; then
    echo "Node.js no está instalado. Instalando..."
    pkg install nodejs -y
fi

termux-setup-storage
echo -e "\033[32mServidor interno de la App habilitado\033[0m"
node index.js
