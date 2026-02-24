#!/bin/bash

# Variables configurables 
DEFAULT_VERSION="_v15.4.5.1pyBeta"
VERSION=${2:-$DEFAULT_VERSION}
NOMBRE_ZIP="DF_VPN-Down${VERSION}.zip"
CARPETA_VPN="${NOMBRE_ZIP%.zip}"

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

# ======================================================
# Función para liberar el puerto 7568
# ======================================================
liberar_puerto() {
    local PUERTO=7568
    imprimir_mensaje "INFO" "$AMARILLO" "Verificando si el puerto $PUERTO está en uso..."

    # Método 1: Usando lsof
    if command -v lsof &> /dev/null; then
        PIDS=$(lsof -t -i :$PUERTO 2>/dev/null)
        if [ -n "$PIDS" ]; then
            imprimir_mensaje "INFO" "$AMARILLO" "Matando procesos en puerto $PUERTO (PIDs: $PIDS)..."
            for PID in $PIDS; do
                kill -9 "$PID" 2>/dev/null
                imprimir_mensaje "INFO" "$VERDE" "Proceso $PID terminado."
            done
            sleep 1
            return
        fi
    fi

    # Método 2: Usando fuser (alternativa)
    if command -v fuser &> /dev/null; then
        PIDS=$(fuser $PUERTO/tcp 2>/dev/null)
        if [ -n "$PIDS" ]; then
            imprimir_mensaje "INFO" "$AMARILLO" "Matando procesos en puerto $PUERTO con fuser..."
            fuser -k $PUERTO/tcp 2>/dev/null
            sleep 1
            return
        fi
    fi

    # Método 3: Usando ss + grep (compatible con Termux)
    if command -v ss &> /dev/null; then
        PIDS=$(ss -tlnp 2>/dev/null | grep ":$PUERTO " | grep -oP 'pid=\K[0-9]+')
        if [ -n "$PIDS" ]; then
            imprimir_mensaje "INFO" "$AMARILLO" "Matando procesos en puerto $PUERTO con ss..."
            for PID in $PIDS; do
                kill -9 "$PID" 2>/dev/null
                imprimir_mensaje "INFO" "$VERDE" "Proceso $PID terminado."
            done
            sleep 1
            return
        fi
    fi

    # Método 4: Usando netstat (última opción)
    if command -v netstat &> /dev/null; then
        PIDS=$(netstat -tlnp 2>/dev/null | grep ":$PUERTO " | awk '{print $7}' | cut -d'/' -f1 | grep -v '-')
        if [ -n "$PIDS" ]; then
            imprimir_mensaje "INFO" "$AMARILLO" "Matando procesos en puerto $PUERTO con netstat..."
            for PID in $PIDS; do
                kill -9 "$PID" 2>/dev/null
                imprimir_mensaje "INFO" "$VERDE" "Proceso $PID terminado."
            done
            sleep 1
            return
        fi
    fi

    imprimir_mensaje "INFO" "$VERDE" "El puerto $PUERTO está libre."
}

# ======================================================
# LIBERAR PUERTO 7568 ANTES DE CUALQUIER COSA
# ======================================================
liberar_puerto

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

# Función para instalar Python3
instalar_python3() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando Python3..."
    if ! pkg install python3 -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar Python3. Intentando reparar..."
        termux-change-repo
        pkg repair
        if ! pkg reinstall coreutils liblz4; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo reparar. Abortando."
            exit 1
        fi
        if ! pkg install python3 -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar Python3. Abortando."
            exit 1
        fi
    fi
}

# Verificar e instalar wget si es necesario
if ! command -v wget &> /dev/null; then
    instalar_wget
fi

# Verificar e instalar Python3 si es necesario
if ! command -v python3 &> /dev/null; then
    instalar_python3
fi

# Descargar y descomprimir VPN si es necesario
if [ ! -f "$NOMBRE_ZIP" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando $NOMBRE_ZIP..."
    wget "https://raw.githubusercontent.com/UserZero075/DownFast/main/$NOMBRE_ZIP"
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando VPN de DevFast..."
    unzip -o "$NOMBRE_ZIP" > /dev/null 2>&1
fi

cd "$CARPETA_VPN/"

# Configurar almacenamiento de Termux si es necesario
if [ ! -d "../storage" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Configurando almacenamiento de Termux..."
    termux-setup-storage
fi

# Iniciar VPN
imprimir_mensaje "ÉXITO" "$VERDE" "VPN DevFast activado!"
python3 main.py
