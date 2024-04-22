#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update -y && apt install -y wget && apt upgrade -y && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh -y && bash InstallTools.sh -y
fi

if [ ! -f "VPN_0.2.0_android.zip" ]; then
    echo "Descargando VPN.zip..."
    wget https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/VPN_0.2.0_android.zip
    unzip -o VPN_0.2.0_android.zip
fi

cd VPN/

# Obtener la versión de Node.js
node_version=$(node -v)
required_version="v20.12.2"

if ! command -v node &> /dev/null; then
    echo "Node.js no está instalado. Instalando..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    unset PREFIX
    nvm use --delete-prefix v20.12.2
    nvm install 20.12.2
fi

# Comparar la versión de Node.js con la versión requerida
#if [[ "$(echo -e "$required_version
#$node_version" | sort -V | head -n1)" == "$required_version" ]]; then
    #echo "Node.js no está actualizado. Actualizando..."
    #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    #source ~/.bashrc
    #nvm install v20.12.2
#fi

echo -e "\033[32mVPN DevFast activado!\033[0m"
node index.js
