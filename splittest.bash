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
GRIS='\033[0;90m'
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
        -D1) IP="$D1"; shift ;;
        -D2) IP="$D2"; shift ;;
        -D3) IP="$D3"; shift ;;
        -D4) IP="$D4"; shift ;;
        -W1) IP="$W1"; shift ;;
        -W2) IP="$W2"; shift ;;
        -W3) IP="$W3"; shift ;;
        -W4) IP="$W4"; shift ;;
        *)
            echo -e "${ROJO}Flag desconocido: $1${NC}"
            echo ""
            echo "Uso: $0 [-CU|-US] [-D1|-D2|-D3|-D4|-W1|-W2|-W3|-W4]"
            exit 1
            ;;
    esac
done

# Validaciones
if [ "$MODO_AUTO" = true ] && [ -z "$IP" ]; then
    echo -e "${ROJO}Error: Debes especificar tanto la región (-CU o -US) como el DNS${NC}"
    exit 1
fi

if [ -n "$IP" ] && [ "$MODO_AUTO" = false ]; then
    echo -e "${ROJO}Error: Debes especificar la región (-CU o -US) junto con el DNS${NC}"
    exit 1
fi

# === VERIFICAR DEPENDENCIAS ===

echo ""
imprimir_mensaje "INFO" "$CYAN" "Verificando dependencias..."

# Brotli
if [ -x "/data/data/com.termux/files/usr/bin/brotli" ]; then
    imprimir_mensaje "OK" "$VERDE" "brotli ✓"
else
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
    yes | pkg install -y brotli 2>/dev/null
    [ -x "/data/data/com.termux/files/usr/bin/brotli" ] && imprimir_mensaje "OK" "$VERDE" "brotli ✓"
fi

# Netcat (para verificación de conexión)
if command -v nc >/dev/null 2>&1; then
    imprimir_mensaje "OK" "$VERDE" "netcat ✓"
else
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando netcat..."
    yes | pkg install -y netcat-openbsd 2>/dev/null
    command -v nc >/dev/null 2>&1 && imprimir_mensaje "OK" "$VERDE" "netcat ✓"
fi

echo ""

# === DESCARGAR SLIPSTREAM ===

SLIP_URL="https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client"

if [ ! -f "slipstream-client" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando slipstream-client..."
    curl -sL -o slipstream-client "$SLIP_URL"
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
                ((sel--)); [ $sel -lt 0 ] && sel=$((total - 1)); mostrar
            elif [[ "$key" == "[B" ]]; then
                ((sel++)); [ $sel -ge $total ] && sel=0; mostrar
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
    local objetivos=(22 322 622 922 1222 1522 1822 2122 2422 2722 3022 3322)

    for objetivo in "${objetivos[@]}"; do
        if [ "$ahora" -lt "$objetivo" ]; then
            echo $((objetivo - ahora))
            return
        fi
    done
    echo $((3600 + 22 - ahora))
}

# ══════════════════════════════════════════════════════════════════
#  SISTEMA DE VERIFICACIÓN DE CONEXIÓN ROBUSTO
# ══════════════════════════════════════════════════════════════════

# Configuración de verificación
CHECK_INTERVAL=5          # Verificar cada 5 segundos
FAIL_THRESHOLD=4          # Fallos consecutivos antes de reconectar
PING_TIMEOUT=10           # Timeout generoso (10 segundos)
CONSECUTIVE_FAILS=0       # Contador de fallos consecutivos
LAST_CHECK_STATUS=""      # Estado de última verificación

# Códigos de retorno:
#   0 = Todo OK
#   1 = Posible problema de red (fallo suave)
#   2 = Proceso muerto (reconexión inmediata)
#   3 = Puerto local no responde (problema grave)

verificar_conexion() {
    local estado_proceso=true
    local estado_puerto_local=true
    local estado_resolver=true
    
    # ─────────────────────────────────────────────────────────
    # NIVEL 1: Verificar que el proceso sigue vivo (instantáneo)
    # ─────────────────────────────────────────────────────────
    if ! kill -0 "$PID" 2>/dev/null; then
        LAST_CHECK_STATUS="PROCESO_MUERTO"
        return 2
    fi
    
    # ─────────────────────────────────────────────────────────
    # NIVEL 2: Verificar puerto local 5201 (conexión rápida)
    # Este siempre debería responder si slipstream funciona
    # ─────────────────────────────────────────────────────────
    if ! timeout 3 bash -c "echo >/dev/tcp/127.0.0.1/5201" 2>/dev/null; then
        # Alternativa con netcat
        if ! nc -z -w 3 127.0.0.1 5201 2>/dev/null; then
            LAST_CHECK_STATUS="PUERTO_LOCAL_CAIDO"
            return 3
        fi
    fi
    
    # ─────────────────────────────────────────────────────────
    # NIVEL 3: Verificar conectividad al resolver DNS
    # Timeout generoso para evitar falsos positivos
    # ─────────────────────────────────────────────────────────
    if ! nc -z -w "$PING_TIMEOUT" "$IP" 53 2>/dev/null; then
        # Fallback: intentar con /dev/tcp
        if ! timeout "$PING_TIMEOUT" bash -c "echo >/dev/tcp/${IP}/53" 2>/dev/null; then
            LAST_CHECK_STATUS="RESOLVER_INACCESIBLE"
            return 1
        fi
    fi
    
    LAST_CHECK_STATUS="OK"
    return 0
}

# Función para mostrar estado de conexión
mostrar_estado_check() {
    local timestamp=$(date '+%H:%M:%S')
    local estado=$1
    local fails=$2
    
    case $estado in
        "OK")
            echo -e "${GRIS}[${timestamp}] Check: ✓ Conexión estable${NC}"
            ;;
        "PROCESO_MUERTO")
            echo -e "${ROJO}[${timestamp}] Check: ✗ Proceso muerto - Reconexión inmediata${NC}"
            ;;
        "PUERTO_LOCAL_CAIDO")
            echo -e "${ROJO}[${timestamp}] Check: ✗ Puerto local no responde - Reconexión inmediata${NC}"
            ;;
        "RESOLVER_INACCESIBLE")
            echo -e "${AMARILLO}[${timestamp}] Check: ⚠ Resolver inaccesible (${fails}/${FAIL_THRESHOLD} fallos)${NC}"
            ;;
    esac
}

# Función para reconectar
reconectar() {
    local razon=$1
    echo ""
    echo -e "${AMARILLO}[$(date '+%H:%M:%S')] ═══════════════════════════════════════${NC}"
    echo -e "${AMARILLO}[$(date '+%H:%M:%S')] Reconectando: $razon${NC}"
    echo -e "${AMARILLO}[$(date '+%H:%M:%S')] ═══════════════════════════════════════${NC}"
    
    # Matar proceso si sigue vivo
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi
    
    sleep 2
    
    # Relanzar
    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=120 \
        --congestion-control=cubic &
    PID=$!
    
    echo -e "${VERDE}[$(date '+%H:%M:%S')] Nuevo PID: $PID${NC}"
    echo ""
    
    CONSECUTIVE_FAILS=0
}

# ══════════════════════════════════════════════════════════════════

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

# === SELECCIÓN (modo interactivo) ===

if [ "$MODO_AUTO" = false ]; then
    sleep 0.5
    menu_flechas "¿Qué región desea?" "CU" "US"
    REGION="$SELECCION_GLOBAL"
    [ "$REGION" = "CU" ] && DOMAIN="$CU" || DOMAIN="$US"

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
echo "═══════════════════════════════════════════════"
echo "   SLIPSTREAM AUTO-RESTART v0.6"
echo "   + Sistema de Verificación Inteligente"
echo "═══════════════════════════════════════════════"
echo ""
echo "Configuración:"
echo -e "  ${CYAN}Región:${NC}     $REGION"
echo -e "  ${CYAN}Dominio:${NC}    $DOMAIN"
echo -e "  ${CYAN}Resolver:${NC}   $IP"
if [ "$MODO_AUTO" = true ]; then
    echo -e "  ${AMARILLO}Modo:${NC}       Automático"
else
    echo -e "  ${VERDE}Modo:${NC}       Interactivo"
fi
echo ""
echo "Verificación de conexión:"
echo -e "  ${CYAN}Intervalo:${NC}  Cada ${CHECK_INTERVAL}s"
echo -e "  ${CYAN}Tolerancia:${NC} ${FAIL_THRESHOLD} fallos consecutivos"
echo -e "  ${CYAN}Timeout:${NC}    ${PING_TIMEOUT}s (evita falsos positivos)"
echo "═══════════════════════════════════════════════"
echo ""

# === BUCLE PRINCIPAL ===

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

    echo -e "${VERDE}[$(date '+%H:%M:%S')] PID: $PID${NC}"
    echo ""

    CONSECUTIVE_FAILS=0
    LAST_SHOWN_FAILS=-1
    
    # Esperar un poco para que el proceso arranque
    sleep 3

    # ═══════════════════════════════════════════════════════════
    # BUCLE DE VIGILANCIA CON VERIFICACIÓN DE CONEXIÓN
    # ═══════════════════════════════════════════════════════════
    
    while [ "$(date +%s)" -lt "$end_ts" ]; do
        
        verificar_conexion
        resultado=$?
        
        case $resultado in
            0)  # Todo OK
                if [ $CONSECUTIVE_FAILS -gt 0 ]; then
                    echo -e "${VERDE}[$(date '+%H:%M:%S')] Conexión recuperada ✓${NC}"
                fi
                CONSECUTIVE_FAILS=0
                ;;
            
            1)  # Fallo suave (resolver inaccesible)
                ((CONSECUTIVE_FAILS++))
                
                # Solo mostrar si cambió el número de fallos
                if [ $CONSECUTIVE_FAILS -ne $LAST_SHOWN_FAILS ]; then
                    mostrar_estado_check "$LAST_CHECK_STATUS" $CONSECUTIVE_FAILS
                    LAST_SHOWN_FAILS=$CONSECUTIVE_FAILS
                fi
                
                # ¿Alcanzó el umbral?
                if [ $CONSECUTIVE_FAILS -ge $FAIL_THRESHOLD ]; then
                    reconectar "Resolver inaccesible por ${CONSECUTIVE_FAILS} intentos"
                fi
                ;;
            
            2)  # Proceso muerto - reconexión inmediata
                mostrar_estado_check "$LAST_CHECK_STATUS" $CONSECUTIVE_FAILS
                reconectar "Proceso terminó inesperadamente"
                ;;
            
            3)  # Puerto local no responde - reconexión inmediata
                mostrar_estado_check "$LAST_CHECK_STATUS" $CONSECUTIVE_FAILS
                reconectar "Puerto local 5201 no responde"
                ;;
        esac
        
        sleep "$CHECK_INTERVAL"
    done

    # ═══════════════════════════════════════════════════════════
    # REINICIO PROGRAMADO (cada 5 minutos en segundo :22)
    # ═══════════════════════════════════════════════════════════
    
    echo ""
    echo -e "${CYAN}[$(date '+%H:%M:%S')] Reinicio programado...${NC}"
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        wait "$PID" 2>/dev/null
    fi
    echo ""
done
