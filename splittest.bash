#!/bin/bash

# Variables globales
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

# === VERIFICAR BROTLI ===

echo ""
imprimir_mensaje "INFO" "$CYAN" "Verificando dependencias..."

if [ -x "/data/data/com.termux/files/usr/bin/brotli" ]; then
    imprimir_mensaje "OK" "$VERDE" "brotli ✓"
else
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
    yes | pkg install -y brotli 2>/dev/null
    if [ -x "/data/data/com.termux/files/usr/bin/brotli" ]; then
        imprimir_mensaje "OK" "$VERDE" "brotli ✓"
    else
        imprimir_mensaje "ERROR" "$ROJO" "brotli falló"
    fi
fi

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

# === FUNCIÓN DE VERIFICACIÓN DE SALUD DEL TÚNEL ===

verificar_tunel() {
    local output
    output=$(ssh -p 5201 \
        -o BatchMode=yes \
        -o NumberOfPasswordPrompts=0 \
        -o PasswordAuthentication=no \
        -o KbdInteractiveAuthentication=no \
        -o ChallengeResponseAuthentication=no \
        -o PubkeyAuthentication=no \
        -o PreferredAuthentications=none \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        -o ConnectionAttempts=1 \
        -o LogLevel=ERROR \
        127.0.0.1 exit 2>&1)
    
    # "Permission denied" significa que la conexión SSH llegó correctamente
    # Cualquier otro error (timeout, connection refused, etc.) indica problema
    if echo "$output" | grep -q "Permission denied"; then
        return 0  # Túnel OK
    else
        return 1  # Túnel caído
    fi
}

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

    # Reinicios: cada 5 minutos en el segundo 22
    local objetivos=(22 322 622 922 1222 1522 1822 2122 2422 2722 3022 3322)

    for objetivo in "${objetivos[@]}"; do
        if [ "$ahora" -lt "$objetivo" ]; then
            echo $((objetivo - ahora))
            return
        fi
    done

    # Próximo objetivo: 00:22 de la hora siguiente
    echo $((3600 + 22 - ahora))
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
echo "   SLIPSTREAM AUTO-RESTART v0.9"
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

# ================== PARÁMETROS DE MONITOREO ==================
CHECK_EVERY=2              # Revisar proceso cada 2 segundos
RETRY_DELAY=3              # Espera antes de relanzar si se cayó
HEALTH_CHECK_INTERVAL=15   # Verificar salud del túnel cada 15 segundos
HEALTH_CHECK_DELAY=8       # Esperar 8s después de iniciar antes de primera verificación
MAX_FALLOS_CONSECUTIVOS=2  # Requiere 2 fallos consecutivos antes de reiniciar
# =============================================================

contador_health=0
fallos_consecutivos=0

while true; do
    espera=$(calcular_espera)
    end_ts=$(( $(date +%s) + espera ))

    echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client..."
    echo "[$(date '+%H:%M:%S')] Próximo reinicio programado en ${espera}s (~$((espera/60))min)"
    echo ""

    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=120 \
        --congestion-control=cubic &
    PID=$!
    
    contador_health=0
    fallos_consecutivos=0
    primera_verificacion=true

    # Vigilar el proceso hasta el próximo reinicio programado
    while [ "$(date +%s)" -lt "$end_ts" ]; do
        # 1. Verificar si el proceso murió
        if ! kill -0 "$PID" 2>/dev/null; then
            echo ""
            echo "[$(date '+%H:%M:%S')] ${AMARILLO}Proceso murió. Reconectando...${NC}"
            sleep "$RETRY_DELAY"
            break  # Salir del while interno para reiniciar
        fi
        
        # 2. Verificar salud del túnel SSH
        contador_health=$((contador_health + CHECK_EVERY))
        
        # Esperar un poco después del inicio antes de la primera verificación
        if [ "$primera_verificacion" = true ]; then
            if [ "$contador_health" -ge "$HEALTH_CHECK_DELAY" ]; then
                primera_verificacion=false
                if ! verificar_tunel; then
                    fallos_consecutivos=$((fallos_consecutivos + 1))
                    echo "[$(date '+%H:%M:%S')] ${AMARILLO}Túnel no responde (intento 1/$MAX_FALLOS_CONSECUTIVOS)${NC}"
                else
                    echo "[$(date '+%H:%M:%S')] ${VERDE}Túnel verificado OK${NC}"
                    fallos_consecutivos=0
                fi
                contador_health=0
            fi
        elif [ "$contador_health" -ge "$HEALTH_CHECK_INTERVAL" ]; then
            if ! verificar_tunel; then
                fallos_consecutivos=$((fallos_consecutivos + 1))
                echo "[$(date '+%H:%M:%S')] ${AMARILLO}Túnel no responde ($fallos_consecutivos/$MAX_FALLOS_CONSECUTIVOS)${NC}"
                
                # Solo reiniciar si alcanzamos el máximo de fallos consecutivos
                if [ "$fallos_consecutivos" -ge "$MAX_FALLOS_CONSECUTIVOS" ]; then
                    echo ""
                    echo "[$(date '+%H:%M:%S')] ${ROJO}Túnel caído ($fallos_consecutivos fallos). Reconectando...${NC}"
                    kill "$PID" 2>/dev/null
                    wait "$PID" 2>/dev/null
                    sleep "$RETRY_DELAY"
                    break
                fi
            else
                if [ "$fallos_consecutivos" -gt 0 ]; then
                    echo "[$(date '+%H:%M:%S')] ${VERDE}Túnel recuperado OK${NC}"
                else
                    echo "[$(date '+%H:%M:%S')] ${VERDE}Túnel OK${NC}"
                fi
                fallos_consecutivos=0
            fi
            contador_health=0
        fi
        
        sleep "$CHECK_EVERY"
    done

    # Reinicio programado
    echo ""
    echo "[$(date '+%H:%M:%S')] Reinicio programado..."
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi
done
