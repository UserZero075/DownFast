#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update -y && apt install -y wget && apt upgrade -y && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh -y && bash InstallTools.sh -y
fi

if [ ! -f "VPN_0.1.0_android.zip" ]; then
    echo "Descargando VPN.zip..."
    wget https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/VPN_0.1.0_android.zip
    unzip -o VPN_0.1.0_android.zip
fi

cd VPN/

if ! command -v node &> /dev/null; then
    echo "Node.js no está instalado. Instalando..."
    pkg install nodejs -y
fi

echo -e "\033[32mVPN DevFast activado!\033[0m"
node index.js
