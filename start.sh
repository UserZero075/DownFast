#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
NC='\033[0m' # Sin Color

# Función para imprimir mensajes con formato
imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Función para comparar versiones
compare_version() {
    local ver1="$1"
    local ver2="$2"
    
    # Extraer números de versión
    ver1_clean=$(echo "$ver1" | sed 's/^index_\|\.js$//g')
    ver2_clean=$(echo "$ver2" | sed 's/^index_\|\.js$//g')
    
    # Comparar versiones usando sort -V
    if [ "$(printf '%s\n' "$ver1_clean" "$ver2_clean" | sort -V | tail -n1)" = "$ver1_clean" ]; then
        if [ "$ver1_clean" != "$ver2_clean" ]; then
            echo "1"  # ver1 > ver2
        else
            echo "0"  # ver1 = ver2
        fi
    else
        echo "-1" # ver1 < ver2
    fi
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

# Función para obtener archivos del repositorio GitHub
obtener_archivos_github() {
    local api_url="https://api.github.com/repos/UserZero075/DownFast/contents"
    local temp_file="$HOME/.github_temp_$$"
    
    # Descargar información del repositorio (sin mensajes de debug aquí)
    if ! wget -q --timeout=30 --user-agent="DownFast-Updater" -O "$temp_file" "$api_url" 2>/dev/null; then
        # Solo retornar error, no imprimir mensaje
        rm -f "$temp_file"
        return 1
    fi
    
    # Verificar que el archivo se descargó correctamente
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Extraer archivos index_*.js usando grep y sed
    local github_files=$(grep -o '"name":"index_[^"]*\.js"' "$temp_file" 2>/dev/null | sed 's/"name":"//g; s/"//g')
    
    if [ -z "$github_files" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Encontrar la versión más alta
    local latest_file=""
    local latest_version="0.0.0"
    
    for file in $github_files; do
        local version=$(echo "$file" | sed 's/^index_\|\.js$//g')
        if [ "$(compare_version "index_${version}.js" "index_${latest_version}.js")" = "1" ]; then
            latest_version="$version"
            latest_file="$file"
        fi
    done
    
    rm -f "$temp_file"
    
    # Solo devolver el nombre del archivo, sin mensajes
    echo "$latest_file"
    return 0
}

# Función para descargar archivo de GitHub
descargar_archivo_github() {
    local filename="$1"
    local output_path="$2"
    local download_url="https://raw.githubusercontent.com/UserZero075/DownFast/main/$filename"
    
    imprimir_mensaje "INFO" "$AZUL" "Descargando: $filename"
    if wget -q --timeout=60 -O "$output_path" "$download_url" 2>/dev/null; then
        imprimir_mensaje "OK" "$VERDE" "Descarga completada"
        return 0
    else
        imprimir_mensaje "ERROR" "$ROJO" "Error al descargar $filename"
        return 1
    fi
}

echo
echo "===================================================="
echo
echo "             DownFast Auto-Updater v1.0"
echo
echo "====================================================="
echo

# Verificar e instalar wget si es necesario
if ! command -v wget &> /dev/null; then
    instalar_wget
fi

# Verificar e instalar Node.js si es necesario
if ! command -v node &> /dev/null; then
    instalar_nodejs
fi

# Verificar si existe la carpeta DevFastVPN
if [ ! -d "DevFastVPN" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Carpeta DevFastVPN no encontrada. Descargando..."
    
    # Descargar DevFastVPN.zip
    if ! wget -q --timeout=60 "https://raw.githubusercontent.com/UserZero075/DownFast/main/DevFastVPN.zip" 2>/dev/null; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al descargar DevFastVPN.zip"
        exit 1
    fi
    
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando DevFast VPN..."
    if ! unzip -o "DevFastVPN.zip" > /dev/null 2>&1; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al descomprimir DevFastVPN.zip"
        exit 1
    fi
    
    # Limpiar archivo zip
    rm -f "DevFastVPN.zip"
    imprimir_mensaje "OK" "$VERDE" "DevFastVPN instalado exitosamente"
fi

cd "DevFastVPN/"

# Crear carpeta VPN si no existe
if [ ! -d "VPN" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Creando carpeta VPN..."
    mkdir -p "VPN"
fi

imprimir_mensaje "INFO" "$AZUL" "Buscando actualizaciones..."

# Obtener la última versión de GitHub
latest_github_file=$(obtener_archivos_github)

if [ $? -ne 0 ] || [ -z "$latest_github_file" ]; then
    imprimir_mensaje "ERROR" "$ROJO" "No se pudo conectar a GitHub o no hay archivos disponibles"
    exit 1
fi

# Limpiar el nombre del archivo por si tiene caracteres extraños
latest_github_file=$(echo "$latest_github_file" | tr -d '\r\n' | sed 's/[^a-zA-Z0-9._-]//g')

latest_version=$(echo "$latest_github_file" | sed 's/^index_\|\.js$//g')
imprimir_mensaje "OK" "$VERDE" "Ultima version disponible: v$latest_version"

# Verificar archivos locales
local_files=$(find VPN -name "index_*.js" 2>/dev/null)
needs_download=false
file_to_execute="$latest_github_file"

if [ -z "$local_files" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Primera instalacion detectada"
    needs_download=true
else
    # Encontrar el archivo local más reciente
    latest_local_file=""
    latest_local_version="0.0.0"
    
    for file in $local_files; do
        filename=$(basename "$file")
        version=$(echo "$filename" | sed 's/^index_\|\.js$//g')
        if [ "$(compare_version "index_${version}.js" "index_${latest_local_version}.js")" = "1" ]; then
            latest_local_version="$version"
            latest_local_file="$filename"
        fi
    done
    
    imprimir_mensaje "INFO" "$CIAN" "Version local: v$latest_local_version"
    
    # Comparar versiones
    if [ "$(compare_version "$latest_github_file" "$latest_local_file")" = "1" ]; then
        imprimir_mensaje "INFO" "$AMARILLO" "Nueva actualizacion disponible"
        needs_download=true
        # Eliminar archivos antiguos
        rm -f VPN/index_*.js
    else
        imprimir_mensaje "OK" "$VERDE" "Tu version esta actualizada"
        file_to_execute="$latest_local_file"
    fi
fi

# Descargar si es necesario
if [ "$needs_download" = true ]; then
    if ! descargar_archivo_github "$latest_github_file" "VPN/$latest_github_file"; then
        exit 1
    fi
fi

# Configurar almacenamiento de Termux si es necesario (suprimiendo warnings del sistema)
if [ ! -d "../storage" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Configurando almacenamiento de Termux..."
    termux-setup-storage 2>/dev/null
fi

# Verificar que el archivo existe
if [ ! -f "VPN/$file_to_execute" ]; then
    imprimir_mensaje "ERROR" "$ROJO" "Archivo no encontrado: $file_to_execute"
    exit 1
fi

echo
imprimir_mensaje "OK" "$VERDE" "Ejecutando: $file_to_execute"
echo
echo "===================================================="
echo "              DOWNFAST INICIADO                     "
echo "===================================================="
echo

# Ejecutar el archivo con Node.js
node "VPN/$file_to_execute"
exit_code=$?

echo
echo "===================================================="

if [ $exit_code -ne 0 ]; then
    imprimir_mensaje "ERROR" "$ROJO" "DownFast termino con errores (Codigo: $exit_code)"
    imprimir_mensaje "INFO" "$AMARILLO" "Revisa los mensajes anteriores para mas detalles"
else
    imprimir_mensaje "OK" "$VERDE" "DownFast ejecutado exitosamente"
fi
