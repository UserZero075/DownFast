#!/bin/bash

# Variables configurables
DEFAULT_VERSION="2.5.5"
VERSION=${2:-$DEFAULT_VERSION}
NOMBRE_ZIP="VPNv${VERSION}.zip"
CARPETA_VPN="${NOMBRE_ZIP%.zip}"

# Verificar si se proporciona el parámetro --version
if [ "$1" = "--version" ] && [ ! -z "$2" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Usando versión $VERSION"
else
    VERSION=$DEFAULT_VERSION
    NOMBRE_ZIP="VPNv${VERSION}.zip"
    imprimir_mensaje "INFO" "$AMARILLO" "Usando versión por defecto $VERSION"
fi

export DEBIAN_FRONTEND=noninteractive

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
NC='\033[0m' # Sin Color

# Función para imprimir mensajes con formato
imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Función para instalar wget
instalar_wget() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando wget..."
    if ! (apt update -y && apt install -y wget && apt upgrade -y); then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar wget. Intentando reparar..."
        apt --fix-broken install -y
        if ! (apt update -y && apt install -y wget && apt upgrade -y); then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar wget. Abortando."
            exit 1
        fi
    fi
    wget https://github.com/MasterDevX/Termux-ADB/raw/master/InstallTools.sh && bash InstallTools.sh
}

# Función para instalar Node.js
instalar_nodejs() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando Node.js..."
    if ! pkg install nodejs-lts -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar Node.js. Intentando reparar..."
        termux-change-repo
        pkg repair
        if ! pkg reinstall coreutils liblz4; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo reparar. Abortando."
            exit 1
        fi
        if ! pkg install nodejs-lts -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar Node.js. Abortando."
            exit 1
        fi
    fi
}

# Verificar e instalar wget si es necesario
if ! command -v wget &> /dev/null; then
    instalar_wget
fi

# Descargar y descomprimir VPN si es necesario
if [ ! -f "$NOMBRE_ZIP" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando $NOMBRE_ZIP..."
    wget "https://raw.githubusercontent.com/UserZero075/DownFast/main/$NOMBRE_ZIP"
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando VPN de DevFast..."
    unzip -o "$NOMBRE_ZIP" > /dev/null 2>&1
fi

cd "$CARPETA_VPN/"

# Verificar e instalar Node.js si es necesario
if ! command -v node &> /dev/null; then
    instalar_nodejs
fi

# Configurar almacenamiento de Termux si es necesario
if [ ! -d "../storage" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Configurando almacenamiento de Termux..."
    termux-setup-storage
fi

# Iniciar VPN
imprimir_mensaje "ÉXITO" "$VERDE" "VPN DevFast activado!"
node VPN/index.js
