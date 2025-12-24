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
            echo -e "${ROJO}Flag desconocido: $1${NC}"
            echo "Uso: $0 [-CU|-US] [-D1|-D2|-D3|-D4|-W1|-W2|-W3|-W4]"
            exit 1
            ;;
    esac
done

if [ "$MODO_AUTO" = true ] && [ -z "$IP" ]; then
    echo -e "${ROJO}Error: Especifica región y DNS${NC}"
    exit 1
fi

if [ -n "$IP" ] && [ "$MODO_AUTO" = false ]; then
    echo -e "${ROJO}Error: Especifica región (-CU o -US)${NC}"
    exit 1
fi

# === DEPENDENCIAS ===

echo ""
imprimir_mensaje "INFO" "$CYAN" "Verificando dependencias..."

if [ -x "/data/data/com.termux/files/usr/bin/brotli" ]; then
    imprimir_mensaje "OK" "$VERDE" "brotli ✓"
else
    yes | pkg install -y brotli 2>/dev/null
fi

if command -v curl >/dev/null 2>&1; then
    imprimir_mensaje "OK" "$VERDE" "curl ✓"
else
    yes | pkg install -y curl 2>/dev/null
fi

echo ""

# === DESCARGAR SLIPSTREAM ===

SLIP_URL="https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client"

if [ ! -f "slipstream-client" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando slipstream-client..."
    curl -sL -o slipstream-client "$SLIP_URL"
fi
chmod +x slipstream-client 2>/dev/null

# === MENÚ ===

SELECCION_GLOBAL=""

menu_flechas() {
    local prompt="$1"
    shift
    local opciones=("$@")
    local sel=0
    local total=${#opciones[@]}

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
            [[ "$key" == "[A" ]] && { ((sel--)); [ $sel -lt 0 ] && sel=$((total-1)); mostrar; }
            [[ "$key" == "[B" ]] && { ((sel++)); [ $sel -ge $total ] && sel=0; mostrar; }
        elif [[ "$key" == "" ]]; then
            SELECCION_GLOBAL="${opciones[$sel]}"
            return 0
        fi
    done
}

calcular_espera() {
    local minuto=$((10#$(date +%M)))
    local segundo=$((10#$(date +%S)))
    local ahora=$((minuto * 60 + segundo))
    local objetivos=(22 322 622 922 1222 1522 1822 2122 2422 2722 3022 3322)

    for objetivo in "${objetivos[@]}"; do
        [ "$ahora" -lt "$objetivo" ] && echo $((objetivo - ahora)) && return
    done
    echo $((3600 + 22 - ahora))
}

# ══════════════════════════════════════════════════════════════════
#  SISTEMA DE VERIFICACIÓN DE CONEXIÓN A INTERNET
# ══════════════════════════════════════════════════════════════════

# Configuración - MUY tolerante para evitar falsos positivos
CHECK_INTERVAL=10           # Verificar cada 10 segundos
FAIL_THRESHOLD=4            # 4 fallos consecutivos = 40 segundos de problema real
CONNECT_TIMEOUT=15          # Timeout de conexión (generoso)
MAX_TIMEOUT=25              # Timeout total (muy generoso para redes saturadas)
CONSECUTIVE_FAILS=0

# URLs de prueba (muy ligeras, solo devuelven código de estado)
# Estas son las URLs que usan Android/iOS para detectar portales cautivos
TEST_URLS=(
    "http://connectivitycheck.gstatic.com/generate_204"    # Google - devuelve 204
    "http://www.msftconnecttest.com/connecttest.txt"       # Microsoft - devuelve 200
    "http://captive.apple.com/hotspot-detect.html"         # Apple - devuelve 200
)

# ─────────────────────────────────────────────────────────────────
# Detectar tipo de proxy que usa slipstream
# ─────────────────────────────────────────────────────────────────
PROXY_TYPE=""

detectar_tipo_proxy() {
    echo -e "${GRIS}[$(date '+%H:%M:%S')] Detectando tipo de proxy...${NC}"
    
    # Probar SOCKS5
    if curl --proxy socks5h://127.0.0.1:5201 \
            -s -o /dev/null \
            --connect-timeout 5 \
            --max-time 10 \
            "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null; then
        PROXY_TYPE="socks5h://127.0.0.1:5201"
        echo -e "${VERDE}[$(date '+%H:%M:%S')] Proxy: SOCKS5 ✓${NC}"
        return 0
    fi
    
    # Probar HTTP proxy
    if curl --proxy http://127.0.0.1:5201 \
            -s -o /dev/null \
            --connect-timeout 5 \
            --max-time 10 \
            "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null; then
        PROXY_TYPE="http://127.0.0.1:5201"
        echo -e "${VERDE}[$(date '+%H:%M:%S')] Proxy: HTTP ✓${NC}"
        return 0
    fi
    
    # No se detectó proxy, usar verificación básica
    PROXY_TYPE=""
    echo -e "${AMARILLO}[$(date '+%H:%M:%S')] Proxy no detectado, usando verificación básica${NC}"
    return 1
}

# ─────────────────────────────────────────────────────────────────
# Verificación principal de conexión
# ─────────────────────────────────────────────────────────────────

# Retorna:
#   0 = Internet OK
#   1 = Sin internet (fallo suave)
#   2 = Proceso muerto
#   3 = Puerto local no responde

verificar_conexion() {
    # ═══════════════════════════════════════════════════════════
    # NIVEL 1: ¿Proceso vivo? (instantáneo)
    # ═══════════════════════════════════════════════════════════
    if ! kill -0 "$PID" 2>/dev/null; then
        return 2
    fi
    
    # ═══════════════════════════════════════════════════════════
    # NIVEL 2: ¿Puerto local responde? (rápido)
    # ═══════════════════════════════════════════════════════════
    if ! timeout 3 bash -c "echo >/dev/tcp/127.0.0.1/5201" 2>/dev/null; then
        return 3
    fi
    
    # ═══════════════════════════════════════════════════════════
    # NIVEL 3: ¿Hay internet real a través del túnel?
    # ═══════════════════════════════════════════════════════════
    
    # Si no tenemos proxy detectado, solo verificar proceso + puerto
    if [ -z "$PROXY_TYPE" ]; then
        return 0
    fi
    
    # Intentar conectar a través del proxy
    local http_code
    local url
    
    for url in "${TEST_URLS[@]}"; do
        http_code=$(curl --proxy "$PROXY_TYPE" \
                         -s -o /dev/null \
                         -w "%{http_code}" \
                         --connect-timeout "$CONNECT_TIMEOUT" \
                         --max-time "$MAX_TIMEOUT" \
                         "$url" 2>/dev/null)
        
        # 204 (Google) o 200 (Microsoft/Apple) = éxito
        if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
            return 0
        fi
    done
    
    # Ninguna URL respondió correctamente
    return 1
}

# ─────────────────────────────────────────────────────────────────
# Función para reconectar
# ─────────────────────────────────────────────────────────────────

reconectar() {
    local razon=$1
    echo ""
    echo -e "${ROJO}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${ROJO}║  $(date '+%H:%M:%S') - RECONECTANDO                          ║${NC}"
    echo -e "${ROJO}║  Razón: $razon${NC}"
    echo -e "${ROJO}╚══════════════════════════════════════════════════╝${NC}"
    
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    sleep 2
    
    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=120 \
        --congestion-control=cubic &
    PID=$!
    
    echo -e "${VERDE}[$(date '+%H:%M:%S')] Nuevo PID: $PID${NC}"
    
    # Esperar que arranque y re-detectar proxy
    sleep 4
    detectar_tipo_proxy
    
    echo ""
    
    CONSECUTIVE_FAILS=0
}

# ══════════════════════════════════════════════════════════════════

PID=""

cleanup() {
    echo ""
    echo "[$(date '+%H:%M:%S')] Deteniendo..."
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    termux-wake-unlock 2>/dev/null
    echo "[$(date '+%H:%M:%S')] Terminado."
    exit 0
}

trap cleanup SIGINT SIGTERM

# === SELECCIÓN INTERACTIVA ===

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
echo "═══════════════════════════════════════════════════════"
echo "   SLIPSTREAM AUTO-RESTART v0.8"
echo "   + Verificación de Internet Real"
echo "═══════════════════════════════════════════════════════"
echo ""
echo -e "  ${CYAN}Región:${NC}       $REGION"
echo -e "  ${CYAN}Dominio:${NC}      $DOMAIN"
echo -e "  ${CYAN}Resolver:${NC}     $IP"
echo -e "  ${CYAN}Modo:${NC}         $([ "$MODO_AUTO" = true ] && echo 'Automático' || echo 'Interactivo')"
echo ""
echo -e "  ${CYAN}Verificación:${NC}"
echo -e "    • Check cada:   ${CHECK_INTERVAL}s"
echo -e "    • Tolerancia:   ${FAIL_THRESHOLD} fallos (=$((FAIL_THRESHOLD * CHECK_INTERVAL))s de problema)"
echo -e "    • Timeout:      ${MAX_TIMEOUT}s (evita falsos positivos)"
echo "═══════════════════════════════════════════════════════"
echo ""

# === BUCLE PRINCIPAL ===

while true; do
    espera=$(calcular_espera)
    end_ts=$(( $(date +%s) + espera ))

    echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client..."
    echo "[$(date '+%H:%M:%S')] Próximo reinicio: ${espera}s (~$((espera/60))min)"
    echo ""

    ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=120 \
        --congestion-control=cubic &
    PID=$!

    echo -e "${VERDE}[$(date '+%H:%M:%S')] PID: $PID${NC}"
    
    CONSECUTIVE_FAILS=0
    
    # Esperar que inicie
    sleep 5
    
    # Detectar tipo de proxy
    detectar_tipo_proxy
    
    echo ""
    echo -e "${GRIS}[$(date '+%H:%M:%S')] Monitoreando conexión...${NC}"
    echo ""

    # ═══════════════════════════════════════════════════════════
    # BUCLE DE VIGILANCIA
    # ═══════════════════════════════════════════════════════════
    
    LAST_STATUS=""
    
    while [ "$(date +%s)" -lt "$end_ts" ]; do
        
        verificar_conexion
        resultado=$?
        
        case $resultado in
            0)  # Internet OK
                if [ $CONSECUTIVE_FAILS -gt 0 ]; then
                    echo -e "${VERDE}[$(date '+%H:%M:%S')] ✓ Conexión restaurada${NC}"
                elif [ "$LAST_STATUS" != "OK" ]; then
                    echo -e "${VERDE}[$(date '+%H:%M:%S')] ✓ Internet funcionando${NC}"
                fi
                CONSECUTIVE_FAILS=0
                LAST_STATUS="OK"
                ;;
            
            1)  # Sin internet
                ((CONSECUTIVE_FAILS++))
                echo -e "${AMARILLO}[$(date '+%H:%M:%S')] ⚠ Sin respuesta de internet (${CONSECUTIVE_FAILS}/${FAIL_THRESHOLD})${NC}"
                LAST_STATUS="NO_INTERNET"
                
                if [ $CONSECUTIVE_FAILS -ge $FAIL_THRESHOLD ]; then
                    reconectar "Sin internet por ${CONSECUTIVE_FAILS} intentos"
                fi
                ;;
            
            2)  # Proceso muerto
                echo -e "${ROJO}[$(date '+%H:%M:%S')] ✗ Proceso muerto${NC}"
                reconectar "Proceso terminó inesperadamente"
                LAST_STATUS="DEAD"
                ;;
            
            3)  # Puerto no responde
                ((CONSECUTIVE_FAILS++))
                echo -e "${AMARILLO}[$(date '+%H:%M:%S')] ⚠ Puerto 5201 no responde (${CONSECUTIVE_FAILS}/${FAIL_THRESHOLD})${NC}"
                LAST_STATUS="PORT_DOWN"
                
                if [ $CONSECUTIVE_FAILS -ge $FAIL_THRESHOLD ]; then
                    reconectar "Puerto local sin respuesta"
                fi
                ;;
        esac
        
        sleep "$CHECK_INTERVAL"
    done

    # Reinicio programado
    echo ""
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ═══ Reinicio programado ═══${NC}"
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    echo ""
done
