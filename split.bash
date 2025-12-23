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

# === FORZAR INSTALACIÓN NO INTERACTIVA ===
export DEBIAN_FRONTEND=noninteractive

termux-wake-lock 2>/dev/null

# Colores
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# ============================================
# VERIFICACIÓN RÁPIDA PARA TERMUX
# ============================================

NECESITA_UPDATE=false

verificar_rapido() {
    local paquete="$1"
    local comando="$2"
    local test_arg="$3"
    
    [ -z "$comando" ] && comando="$paquete"
    [ -z "$test_arg" ] && test_arg="--version"
    
    # Verificación simple: solo si existe el comando
    if command -v "$comando" &>/dev/null; then
        imprimir_mensaje "OK" "$VERDE" "$paquete ✓"
        return 0
    fi
    
    # Si llegamos aquí, necesitamos instalar
    if [ "$NECESITA_UPDATE" = false ]; then
        NECESITA_UPDATE=true
        imprimir_mensaje "INFO" "$AMARILLO" "Actualizando repositorios..."
        yes | pkg update 2>/dev/null
    fi
    
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando $paquete..."
    yes | pkg install -y "$paquete" 2>/dev/null
    hash -r 2>/dev/null
    
    if command -v "$comando" &>/dev/null; then
        imprimir_mensaje "OK" "$VERDE" "$paquete ✓"
        return 0
    else
        # Segundo intento: reinstalar
        imprimir_mensaje "WARN" "$AMARILLO" "Reintentando $paquete..."
        yes | pkg reinstall -y "$paquete" 2>/dev/null
        hash -r 2>/dev/null
        
        if command -v "$comando" &>/dev/null; then
            imprimir_mensaje "OK" "$VERDE" "$paquete ✓"
            return 0
        else
            imprimir_mensaje "ERROR" "$ROJO" "$paquete falló"
            return 1
        fi
    fi
}

# === PARSEO DE ARGUMENTOS ===

MODO_AUTO=false
DOMAIN=""
IP=""
REGION=""

while [[ $# -gt 0 ]]; do
    case ${1^^} in
        -CU)
            REGION="CU"
            DOMAIN="$CU"
            MODO_AUTO=true
            shift
            ;;
        -US)
            REGION="US"
            DOMAIN="$US"
            MODO_AUTO=true
            shift
            ;;
        -D1)
            IP="$D1"
            shift
            ;;
        -D2)
            IP="$D2"
            shift
            ;;
        -D3)
            IP="$D3"
            shift
            ;;
        -D4)
            IP="$D4"
            shift
            ;;
        -W1)
            IP="$W1"
            shift
            ;;
        -W2)
            IP="$W2"
            shift
            ;;
        -W3)
            IP="$W3"
            shift
            ;;
        -W4)
            IP="$W4"
            shift
            ;;
        *)
            echo -e "${ROJO}Flag desconocido: $1${NC}"
            echo ""
            echo "Uso: $0 [-CU|-US] [-D1|-D2|-D3|-D4|-W1|-W2|-W3|-W4]"
            echo ""
            echo "Ejemplos:"
            echo "  $0 -CU -D1     # Región CU con DNS Datos 1"
            echo "  $0 -US -W2     # Región US con DNS WiFi 2"
            echo "  $0             # Modo interactivo (menú)"
            exit 1
            ;;
    esac
done

# Validaciones
if [ "$MODO_AUTO" = true ] && [ -z "$IP" ]; then
    echo -e "${ROJO}Error: Debes especificar tanto la región (-CU o -US) como el DNS (-D1, -D2, -W1, etc.)${NC}"
    exit 1
fi

if [ -n "$IP" ] && [ "$MODO_AUTO" = false ]; then
    echo -e "${ROJO}Error: Debes especificar la región (-CU o -US) junto con el DNS${NC}"
    exit 1
fi

# === VERIFICACIONES RÁPIDAS ===

echo ""
imprimir_mensaje "INFO" "$CYAN" "Verificando dependencias..."

# Solo verificamos si el comando existe (sin ejecutar argumentos problemáticos)
verificar_rapido "openssl" "openssl"
verificar_rapido "dos2unix" "dos2unix"
verificar_rapido "brotli" "brotli"
verificar_rapido "curl" "curl"

echo ""

# === DESCARGAR SLIPSTREAM ===

SLIP_URL="https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client"

if [ ! -f "slipstream-client" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando slipstream-client..."
    curl -sL -o slipstream-client "$SLIP_URL"
    chmod +x slipstream-client
else
    imprimir_mensaje "OK" "$VERDE" "slipstream-client ✓"
fi

chmod +x slipstream-client 2>/dev/null

# === MENÚ CON FLECHAS ===

SELECCION_GLOBAL=""

menu_flechas() {
    local prompt="$1"
    shift
    local opciones=("$@")
    local sel=0
    local total=${#opciones[@]}
    local key
    
    mostrar() {
        clear
        echo ""
        echo "========================================="
        echo -e "${CYAN}  $prompt${NC}"
        echo "========================================="
        echo ""
        
        for i in "${!opciones[@]}"; do
            if [ $i -eq $sel ]; then
                echo -e "   ${VERDE}▶ ${opciones[$i]}${NC}"
            else
                echo "     ${opciones[$i]}"
            fi
        done
        
        echo ""
        echo "-----------------------------------------"
        echo "  Usa ↑↓ para moverte, Enter para elegir"
        echo "-----------------------------------------"
    }
    
    mostrar
    
    while true; do
        IFS= read -rsn1 key
        
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            if [[ "$key" == "[A" ]]; then
                ((sel--))
                [ $sel -lt 0 ] && sel=$((total - 1))
                mostrar
            elif [[ "$key" == "[B" ]]; then
                ((sel++))
                [ $sel -ge $total ] && sel=0
                mostrar
            fi
        elif [[ "$key" == "" ]]; then
            SELECCION_GLOBAL="${opciones[$sel]}"
            return 0
        fi
    done
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
    termux-wake-unlock 2>/dev/null
    echo "[$(date '+%H:%M:%S')] Terminado."
    exit 0
}

trap cleanup SIGINT SIGTERM

# === SELECCIÓN ===

if [ "$MODO_AUTO" = false ]; then
    sleep 0.5

    menu_flechas "¿Qué región desea?" "CU" "US"
    REGION="$SELECCION_GLOBAL"
    if [ "$REGION" = "CU" ]; then
        DOMAIN="$CU"
    else
        DOMAIN="$US"
    fi

    menu_flechas "¿Tipo de conexión?" "Datos móviles" "WiFi"
    TIPO_RED="$SELECCION_GLOBAL"
    if [ "$TIPO_RED" = "Datos móviles" ]; then
        menu_flechas "¿IP del resolver?" "$D1" "$D2" "$D3" "$D4"
    else
        menu_flechas "¿IP del resolver?" "$W1" "$W2" "$W3" "$W4"
    fi
    IP="$SELECCION_GLOBAL"
fi

# === PANTALLA PRINCIPAL ===

clear
echo "========================================="
echo "   SLIPSTREAM AUTO-RESTART"
echo "========================================="
echo "Reinicios: XX:07:30, XX:17:30, XX:27:30,"
echo "           XX:37:30, XX:47:30, XX:57:30"
echo "Presiona Ctrl+C para detener"
echo "========================================="
echo ""
echo "Configuración:"
echo -e "  ${CYAN}Región:${NC}   $REGION"
echo -e "  ${CYAN}Dominio:${NC}  $DOMAIN"
echo -e "  ${CYAN}Resolver:${NC} $IP"
if [ "$MODO_AUTO" = true ]; then
    echo -e "  ${AMARILLO}Modo:${NC}     Automático (sin menú)"
else
    echo -e "  ${VERDE}Modo:${NC}     Interactivo"
fi
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
        --keep-alive-interval=120 \
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
