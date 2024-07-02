#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update -y && apt install -y wget && apt upgrade -y && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh -y && bash InstallTools.sh -y
fi

mv VPN_0.6.0_android.zip VPN_0.6.5_android.zip

cd VPN/

wget -O VPN/index.js https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/index_down.js

# Ejecutamos el script correspondiente según la respuesta
if [[ "$usar_megas" == "s" || "$usar_megas" == "S" ]]; then
    echo -e "\033[32mVPN DevFast activado y desactualizado (1)!\033[0m"
    node VPN/index.js
else
    echo -e "\033[32mVPN DevFast activado y desactualizado (2)!\033[0m"
    node VPN/index2.js
fi
