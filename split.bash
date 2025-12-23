#!/bin/bash

# ================== VARIABLES GLOBALES ==================

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
termux-wake-lock 2>/dev/null

# ================== COLORES ==================

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# ================== PARSEO ARGUMENTOS ==================

MODO_AUTO=false
DOMAIN=""
IP=""
REGION=""

while [[ $# -gt 0 ]]; do
    case ${1^^} in
        -CU) REGION="CU"; DOMAIN="$CU"; MODO_AUTO=true; shift ;;
        -US) REGION="US"; DOMAIN="$US"; MODO_AUTO=true; shift ;;
        -D1) IP="$D1"; shift ;;
        -D2) IP="$D2"; shift ;;
        -D3) IP="$D3"; shift ;;
        -D4) IP="$D4"; shift ;;
        -W1) IP="$W1"; shift ;;
        -W2) IP="$W2"; shift ;;
        -W3) IP="$W3"; shift ;;
        -W4) IP="$W4"; shift ;;
        *)
            echo "Uso: $0 [-CU|-US] [-D1|-D2|-D3|-D4|-W1|-W2|-W3|-W4]"
            exit 1
            ;;
    esac
done

if [ "$MODO_AUTO" = true ] && [ -z "$IP" ]; then
    imprimir_mensaje "ERROR" "$ROJO" "Falta IP del resolver"
    exit 1
fi

# ================== DEPENDENCIAS ==================

imprimir_mensaje "INFO" "$CYAN" "Verificando brotli..."

if ! command -v brotli >/dev/null; then
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
    yes | pkg install brotli >/dev/null 2>&1
fi

# ================== DESCARGA CLIENTE ==================

SLIP_URL="https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client"

if [ ! -f slipstream-client ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando slipstream-client..."
    curl -sL -o slipstream-client "$SLIP_URL"
    chmod +x slipstream-client
fi

# ================== MENÚ INTERACTIVO ==================

SELECCION_GLOBAL=""

menu_flechas() {
    local prompt="$1"; shift
    local opciones=("$@")
    local sel=0 total=${#opciones[@]} key

    while true; do
        clear
        echo -e "${CYAN}$prompt${NC}"
        echo "--------------------------"
        for i in "${!opciones[@]}"; do
            [[ $i -eq $sel ]] && echo -e "${VERDE}▶ ${opciones[$i]}${NC}" || echo "  ${opciones[$i]}"
        done
        read -rsn1 key
        [[ "$key" == $'\x1b' ]] && read -rsn2 key && {
            [[ "$key" == "[A" ]] && ((sel=(sel-1+total)%total))
            [[ "$key" == "[B" ]] && ((sel=(sel+1)%total))
        }
        [[ "$key" == "" ]] && SELECCION_GLOBAL="${opciones[$sel]}" && return
    done
}

if [ "$MODO_AUTO" = false ]; then
    menu_flechas "Seleccione región:" "CU" "US"
    REGION="$SELECCION_GLOBAL"
    DOMAIN=$([[ "$REGION" == "CU" ]] && echo "$CU" || echo "$US")

    menu_flechas "Tipo de conexión:" "Datos móviles" "WiFi"
    if [[ "$SELECCION_GLOBAL" == "Datos móviles" ]]; then
        menu_flechas "Resolver:" "$D1" "$D2" "$D3" "$D4"
    else
        menu_flechas "Resolver:" "$W1" "$W2" "$W3" "$W4"
    fi
    IP="$SELECCION_GLOBAL"
fi

# ================== RECONEXIÓN AUTOMÁTICA ==================

RETRY_BASE=2
RETRY_MAX=30
CHECK_EVERY=2
PID=""

calcular_espera() {
    local m=$(date +%M) s=$(date +%S)
    local now=$((10#$m*60 + 10#$s))
    for t in 450 1050 1650 2250 2850 3450; do
        (( now < t )) && echo $((t-now)) && return
    done
    echo $((3600 + 450 - now))
}

iniciar_client() {
    echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client"
    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=120 \
        --congestion-control=cubic \
        >/dev/null 2>&1 &
    PID=$!
}

cleanup() {
    echo "Deteniendo..."
    kill "$PID" 2>/dev/null
    termux-wake-unlock 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# ================== LOOP PRINCIPAL ==================

clear
echo "========================================="
echo " SLIPSTREAM AUTO-RECONNECT + RESTART v0.3"
echo "========================================="
echo "Región: $REGION"
echo "Dominio: $DOMAIN"
echo "Resolver: $IP"
echo "========================================="

while true; do
    espera=$(calcular_espera)
    limite=$(( $(date +%s) + espera ))
    backoff=$RETRY_BASE

    iniciar_client

    while (( $(date +%s) < limite )); do
        if ! kill -0 "$PID" 2>/dev/null; then
            echo "[$(date '+%H:%M:%S')] Conexión caída → reconectando en ${backoff}s"
            sleep "$backoff"
            backoff=$((backoff*2)); ((backoff>RETRY_MAX)) && backoff=$RETRY_MAX
            iniciar_client
        else
            sleep "$CHECK_EVERY"
        fi
    done

    echo "[$(date '+%H:%M:%S')] Reinicio programado"
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
done
