#!/bin/bash

if ! command -v wget &> /dev/null; then
    echo "wget no está instalado. Instalando..."
    apt update -y && apt install -y wget && apt upgrade -y && wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh -y && bash InstallTools.sh -y
fi

if [ ! -f "VPN_0.6.5_android.zip" ]; then
    echo "Descargando VPN.zip..."
    wget https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/VPN_0.6.5_android.zip
    unzip -o VPN_0.6.5_android.zip
fi

cd VPN/

# Obtener la versión de Node.js
node_version=$(node -v)
required_version="v20.12.2"

if ! command -v node &> /dev/null; then
    echo "Node.js no está instalado. Instalando..."
    pkg install nodejs-lts -y
fi

# Comparar la versión de Node.js con la versión requerida
#if [[ "$(echo -e "$required_version
#$node_version" | sort -V | head -n1)" == "$required_version" ]]; then
    #echo "Node.js no está actualizado. Actualizando..."
    #curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
    #source ~/.bashrc
    #nvm install v20.12.2
#fi

if [ ! -d "../storage" ]; then
    termux-setup-storage
fi

# Pregunta al usuario si quiere usar Megas
read -p "¿ESTAS DESCARGANDO DESDE UNA LINEA CON MEGAS? (s/n): " usar_megas

# Ejecutamos el script correspondiente según la respuesta
if [[ "$usar_megas" == "s" || "$usar_megas" == "S" ]]; then
    echo -e "\033[32mVPN DevFast activado (1)!\033[0m"
    node VPN/index.js
else
    echo -e "\033[32mVPN DevFast activado (2)!\033[0m"
    node VPN/index2.js
fi
