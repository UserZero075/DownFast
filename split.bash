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
NC='\033[0m'

imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

instalar_wget() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando wget..."
    if ! pkg install wget -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar wget. Intentando reparar..."
        termux-change-repo
        pkg repair
        pkg reinstall coreutils liblz4
        if ! pkg install wget -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar wget. Abortando."
            exit 1
        fi
    fi
}

instalar_openssl() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando openssl..."
    if ! pkg install openssl -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar openssl. Intentando reparar..."
        termux-change-repo
        pkg repair
        pkg reinstall coreutils liblz4
        if ! pkg install openssl -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar openssl. Abortando."
            exit 1
        fi
    fi
}

instalar_brotli() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
    if ! pkg install brotli -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar brotli. Intentando reparar..."
        termux-change-repo
        pkg repair
        pkg reinstall coreutils liblz4
        if ! pkg install brotli -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar brotli. Abortando."
            exit 1
        fi
    fi
}

instalar_dos2unix() {
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando dos2unix..."
    if ! pkg install dos2unix -y; then
        imprimir_mensaje "ERROR" "$ROJO" "Error al instalar dos2unix. Intentando reparar..."
        termux-change-repo
        pkg repair
        pkg reinstall coreutils liblz4
        if ! pkg install dos2unix -y; then
            imprimir_mensaje "ERROR" "$ROJO" "No se pudo instalar dos2unix. Abortando."
            exit 1
        fi
    fi
}

# === VERIFICACIONES EN ORDEN ===

# 1. wget primero (necesario para descargas)
if ! command -v wget &> /dev/null; then
    instalar_wget
fi

# 2. Descargar slipstream-client si no existe
if [ ! -f "slipstream-client" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando slipstream-client..."
    wget https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client
    chmod +x slipstream-client
fi

# 3. Resto de dependencias
if ! command -v openssl &> /dev/null; then
    instalar_openssl
fi

if ! command -v dos2unix &> /dev/null; then
    instalar_dos2unix
fi

if ! command -v brotli &> /dev/null; then
    instalar_brotli
fi

# === FUNCIONES DEL MENÚ Y LÓGICA ===

menu_select() {
    local prompt="$1"; shift
    local options=("$@")
    local selected=0
    local key
    
    printf '\033[?25l'
    
    while true; do
        echo "$prompt"
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                printf "${VERDE}> %s${NC}\n" "${options[$i]}"
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
    
    printf '\033[?25h'
    
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
    printf '\033[?25h'
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

clear
echo "========================================="
echo "   SLIPSTREAM AUTO-RESTART"
echo "========================================="
echo "Reinicios: XX:07:30, XX:17:30, XX:27:30,"
echo "           XX:37:30, XX:47:30, XX:57:30"
echo "Presiona Ctrl+C para detener todo"
echo "========================================="
echo ""

REGION=$(menu_select "¿Qué región desea?" "CU" "US")
if [ "$REGION" = "CU" ]; then
    DOMAIN="$CU"
else
    DOMAIN="$US"
fi

TIPO_RED=$(menu_select "¿Usarás datos móviles o WiFi?" "Datos móviles" "WiFi")
if [ "$TIPO_RED" = "Datos móviles" ]; then
    IP=$(menu_select "¿A qué IP desea resolver?" "$D1" "$D2" "$D3" "$D4")
else
    IP=$(menu_select "¿A qué IP desea resolver?" "$W1" "$W2" "$W3" "$W4")
fi

echo ""
echo "========================================="
echo "Configuración:"
echo "  Región: $REGION"
echo "  Dominio: $DOMAIN"
echo "  Resolver: $IP"
echo "========================================="
echo ""

while true; do
    espera=$(calcular_espera)
    echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client..."
    echo "[$(date '+%H:%M:%S')] Próximo reinicio en ${espera}s (~$((espera/60))min)"
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
