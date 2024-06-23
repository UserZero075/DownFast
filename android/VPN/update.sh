#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update -y && apt install -y wget && apt upgrade -y && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh -y && bash InstallTools.sh -y
fi

mv VPN_0.5.8_android.zip VPN_0.5.9_android.zip

cd VPN/

wget -O VPN/index.js https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/index.js

echo -e "\033[32mVPN DevFast activado y actualizado!\033[0m"
node VPN/index.js
