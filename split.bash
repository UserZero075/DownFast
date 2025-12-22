#!/bin/bash

# Variables configurables 
CU='dns.devfastfree.linkpc.net'
US='dns.devfastfreeus.linkpc.net'

D1='200.55.128.130'
D2='200.55.128.140'
D3='200.55.128.230'
D4='200.55.128.250'

W1='181.225.233.30'
W2='181.225.233.40'
W3='181.225.233.110'
W4='181.225.233.120'

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

# Función para instalar openssl
instalar_openssl() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando openssl..."
    if ! pkg install openssl -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar openssl. Intentando reparar..."
        termux-change-repo
        pkg repair
        if ! pkg reinstall coreutils liblz4; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo reparar. Abortando."
            exit 1
        fi
        if ! pkg install openssl -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar openssl. Abortando."
            exit 1
        fi
    fi
}

# Función para instalar brotli
instalar_brotli() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
    if ! pkg install brotli -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar brotli. Intentando reparar..."
        termux-change-repo
        pkg repair
        if ! pkg reinstall coreutils liblz4; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo reparar. Abortando."
            exit 1
        fi
        if ! pkg install brotli -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar brotli. Abortando."
            exit 1
        fi
    fi
}
 
 # Función para instalar dos2unix
instalar_dos2unix() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando dos2unix..."
    if ! pkg install dos2unix -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar dos2unix. Intentando reparar..."
        termux-change-repo
        pkg repair
        if ! pkg reinstall coreutils liblz4; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo reparar. Abortando."
            exit 1
        fi
        if ! pkg install dos2unix -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar dos2unix. Abortando."
            exit 1
        fi
    fi
}

# Función para instalar slipstream-client
if [ ! -f "slipstream-client" ]; then
    wget https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client
    chmod +x slipstream-client
fi

# Verificar e instalar openssl si es necesario
if ! command -v openssl &> /dev/null; then
    instalar_openssl
fi

# Verificar e instalar dos2unix si es necesario
if ! command -v dos2unix &> /dev/null; then
    instalar_dos2unix
fi

# Verificar e instalar brotli si es necesario
if ! command -v brotli &> /dev/null; then
    instalar_brotli
fi
menu_select() {
    local prompt="$1"; shift
    local options=("$@")
    local selected=0
    local key
    tput civis
    while true; do
        echo "$prompt"
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                printf "> %s\n" "${options[$i]}"
            else
                printf "  %s\n" "${options[$i]}"
            fi
        done
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            if [[ "$key" == "[A" ]]; then
                selected=$(( (selected - 1 + ${#options[@]}) % ${#options[@]} ))
            elif [[ "$key" == "[B" ]]; then
                selected=$(( (selected + 1) % ${#options[@]} ))
            fi
        elif [[ "$key" == "" || "$key" == $'\n' ]]; then
            break
        fi
        printf "\033[%dA" $((${#options[@]}+1))
    done
    printf "\033[%dB" $((${#options[@]}))
    tput cnorm
    echo "${options[$selected]}"
}
calcular_espera() {
    local minuto=$(date +%M)
    local segundo=$(date +%S)
    minuto=$((10#$minuto))
    segundo=$((10#$segundo))
    local ahora=$((minuto * 60 + segundo))
    local objetivos=(450 1050 1650 2250 2850 3450)
    for objetivo in "${objetivos[@]}"; do
        if [ "$ahora" -lt "$objetivo" ]; then
            echo $((objetivo - ahora))
            return
        fi
    done
    echo $((3600 + 450 - ahora))
}
PID=""
cleanup() {
    echo ""
    echo "[$(date '+%H:%M:%S')] Deteniendo..."
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi
    echo "[$(date '+%H:%M:%S')] Terminado."
    exit 0
}
trap cleanup SIGINT SIGTERM
echo "========================================="
echo "   SLIPSTREAM AUTO-RESTART"
echo "========================================="
echo "Reinicios: XX:07:30, XX:17:30, XX:27:30,"
echo "           XX:37:30, XX:47:30, XX:57:30"
echo "Presiona Ctrl+C para detener todo"
echo "========================================="
echo ""
REGION=$(menu_select "Que región desea?" "CU" "US")
if [ "$REGION" = "CU" ]; then
    DOMAIN="$CU"
else
    DOMAIN="$US"
fi
TIPO_RED=$(menu_select "Usarás datos móviles o WiFi?" "Datos móviles" "WiFi")
if [ "$TIPO_RED" = "Datos móviles" ]; then
    IP=$(menu_select "¿A qué IP desea resolver?" "$D1" "$D2" "$D3" "$D4")
else
    IP=$(menu_select "¿A qué IP desea resolver?" "$W1" "$W2" "$W3" "$W4")
fi
while true; do
    espera=$(calcular_espera)
    echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client..."
    echo "[$(date '+%H:%M:%S')] Proximo reinicio en ${espera}s (~$((espera/60))min)"
    echo ""
    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=600 \
        --congestion-control=cubic &
    PID=$!
    sleep "$espera"
    echo ""
    echo "[$(date '+%H:%M:%S')] Reiniciando slipstream-client..."
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi
done
