#!/bin/bash

# Variables configurables
NOMBRE_ZIP="VPNv1.0.2.BETA.zip"
VERSION="1.0.2.BETA"
VERSION_ANTERIOR="VPNv1.0.0"
VERSION_URL="https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/version.txt"
CARPETA_VPN="${NOMBRE_ZIP%.zip}"

export DEBIAN_FRONTEND=noninteractive

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin Color

# Función para imprimir mensajes con formato
imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Función para verificar actualizaciones
verificar_actualizacion() {
    if ! command -v wget &> /dev/null; then
        return 1
    fi

    imprimir_mensaje "INFO" "$CYAN" "Verificando actualizaciones..."
    
    if [ "$ULTIMA_VERSION" != "$VERSION" ] && [ ! -f "$NOMBRE_ZIP" ]; then
        echo -e "\n${AMARILLO}╔═══════════════════════════════════════════════╗${NC}"
        echo -e "${AMARILLO}║         ¡Nueva versión disponible!            ║${NC}"
        echo -e "${AMARILLO}╚═══════════════════════════════════════════════╝${NC}"
        echo -e "\n${CYAN}Versión actual:${NC} ${VERSION_ANTERIOR#VPNv}"
        echo -e "${VERDE}Nueva versión:${NC} $VERSION\n"

        mostrar_changelog
        
        # Método más compatible para Termux
        while true; do
            echo -n "¿Desea actualizar ahora? (s/n): "
            read -n 1 respuesta
            echo ""  # Nueva línea después de la respuesta
            
            case "$respuesta" in
                [sS])
                    imprimir_mensaje "INFO" "$VERDE" "Iniciando actualización..."
                    if [ -d "$CARPETA_VPN" ]; then
                        mv "$CARPETA_VPN" "${CARPETA_VPN}_backup_$(date +%Y%m%d_%H%M%S)"
                    fi
                    rm -f "$NOMBRE_ZIP"
                    return 0
                    ;;
                [nN])
                    imprimir_mensaje "INFO" "$AMARILLO" "Actualización pospuesta"
                    return 1
                    ;;
                *)
                    echo "Por favor, responde 's' para sí o 'n' para no."
                    ;;
            esac
        done
    fi
    return 1
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

# Función para mostrar el registro de cambios
mostrar_changelog() {
    echo -e "\n${VERDE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${VERDE}      REGISTRO DE CAMBIOS VPN ${VERSION}        ${NC}"
    echo -e "${VERDE}╚═══════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${AMARILLO}🚀 Mejoras Principales:${NC}"
    echo -e "  ${VERDE}•${NC} Sistema mejorado de descargas OJS (Revistas)"
    echo -e "  ${VERDE}•${NC} Mejor manejo de reconexiones automáticas"
    echo -e "  ${VERDE}•${NC} Mayor estabilidad en las descargas"
    echo -e "  ${VERDE}•${NC} Prevención de descargas duplicadas"
    
    echo -e "\n${AMARILLO}🎯 Beneficios para el Usuario:${NC}"
    echo -e "  ${VERDE}1.${NC} Descargas más Estables"
    echo -e "     • Menos errores durante la descarga"
    echo -e "     • Mejor recuperación ante fallos de conexión"
    echo -e "  ${VERDE}2.${NC} Mejor Experiencia"
    echo -e "     • Las descargas se cancelan correctamente"
    echo -e "     • No se permiten descargas duplicadas"
    echo -e "     • Mensajes de error más claros"
    echo -e "  ${VERDE}3.${NC} Optimización de Recursos"
    echo -e "     • Menor consumo de memoria"
    echo -e "     • Mejor rendimiento general"
    
    echo -e "\n${AMARILLO}🐛 Problemas Resueltos:${NC}"
    echo -e "  ${VERDE}•${NC} Descargas que quedaban 'atascadas'"
    echo -e "  ${VERDE}•${NC} Errores al cancelar descargas"
    echo -e "  ${VERDE}•${NC} Problemas de reconexión automática"
    
    echo -e "\n${AMARILLO}📝 Nota:${NC}"
    echo -e "  ${VERDE}•${NC} Si las descargas de catalogo (upspe) se les queda atascada, repórtenlo."
    echo -e "  ${VERDE}•${NC} Esto es una versión BETA, puede que tenga errores."
    
    echo -e "\n${VERDE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${VERDE}║         ¡Gracias por usar DevFast VPN!        ║${NC}"
    echo -e "${VERDE}╚═══════════════════════════════════════════════╝${NC}\n"
}

# Verificar e instalar wget si es necesario
if ! command -v wget &> /dev/null; then
    instalar_wget
fi

# Verificar actualizaciones antes de continuar
verificar_actualizacion
necesita_actualizar=$?

# Descargar y descomprimir VPN si es necesario o si hay actualización
if [ ! -f "$NOMBRE_ZIP" ] && [ "$necesita_actualizar" = "0" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando $NOMBRE_ZIP..."
    wget "https://raw.githubusercontent.com/UserZero075/DownFast/main/android/VPN/$NOMBRE_ZIP"
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando VPN de DevFast..."
    unzip -o "$NOMBRE_ZIP" > /dev/null 2>&1
fi

if [ -f "$NOMBRE_ZIP" ]; then
    cd "$CARPETA_VPN/"
else
    cd "$VERSION_ANTERIOR/"
fi

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
imprimir_mensaje "ÉXITO" "$VERDE" "VPN DevFast $VERSION activado!"
if ! node VPN/index.js; then
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando dependencias adicionales..."
    npm install form-data tough-cookie axios-cookiejar-support
    if ! node VPN/index.js; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al ejecutar VPN/index.js: $?"
        exit 1
    fi
fi
