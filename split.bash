#!/bin/bash

# Variables globales
CU='dns.devfastfree.linkpc.net'
US='dns.devfastfreeus.linkpc.net'
#EU='dns.devfastfreeeu.linkpc.net'
#CA='dns.devfastfreeca.linkpc.net'

D1='200.55.128.130'
D2='200.55.128.140'
D3='200.55.128.230'
D4='200.55.128.250'

W1='181.225.233.30'
W2='181.225.233.40'
W3='181.225.233.110'
W4='181.225.233.120'

# === NOMBRE DEL SCRIPT PARA DETECCIÓN ===
SCRIPT_NAME="$(basename "$0")"
LOCK_FILE="${PREFIX:-/data/data/com.termux/files/usr}/tmp/slipstream_launcher.lock"
MY_PID=$$

# === FORZAR INSTALACIÓN NO INTERACTIVA ===
export DEBIAN_FRONTEND=noninteractive

termux-wake-lock 2>/dev/null

# Colores mejorados
ROJO='\033[1;31m'
VERDE='\033[1;32m'
AMARILLO='\033[1;33m'
AZUL='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
BLANCO='\033[1;37m'
GRIS='\033[0;90m'
NC='\033[0m'

# Símbolos Unicode (sin emojis gráficos)
SYM_CHECK="✓"
SYM_ERROR="✗"
SYM_INFO="ℹ"
SYM_WARN="⚠"
SYM_ROCKET="▶"
SYM_CLOCK="○"
SYM_REFRESH="↻"
SYM_SKULL="✖"
SYM_LINK="→"
SYM_CONFIG="●"
SYM_SEARCH="◎"
SYM_CLEAN="◆"
SYM_KILL="✖"
SYM_PULSE="♦"
SYM_DEAD="✖"
SYM_STOP="■"
SYM_WAIT="◌"

imprimir_mensaje() {
    local tipo="$1"
    local color="$2"
    local mensaje="$3"
    local simbolo=""
    
    case "$tipo" in
        "OK") simbolo="$SYM_CHECK" ;;
        "ERROR") simbolo="$SYM_ERROR" ;;
        "INFO") simbolo="$SYM_INFO" ;;
        "WARN") simbolo="$SYM_WARN" ;;
        *) simbolo="$tipo" ;;
    esac
    
    echo -e "${color}${simbolo} ${mensaje}${NC}"
}

# === PARSEO DE ARGUMENTOS ===

MODO_AUTO=false
DOMAIN=""
IP=""
REGION=""
TIMEOUT_RAW_BYTES=6  # Valor por defecto

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
        -EU)
            REGION="EU"
            DOMAIN="$EU"
            MODO_AUTO=true
            shift
            ;;
        -CA)
            REGION="CA"
            DOMAIN="$CA"
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
        -T1)
            TIMEOUT_RAW_BYTES=1
            shift
            ;;
        -T2)
            TIMEOUT_RAW_BYTES=2
            shift
            ;;
        -T3)
            TIMEOUT_RAW_BYTES=3
            shift
            ;;
        -T4)
            TIMEOUT_RAW_BYTES=4
            shift
            ;;
        -T5)
            TIMEOUT_RAW_BYTES=5
            shift
            ;;
        -T6)
            TIMEOUT_RAW_BYTES=6
            shift
            ;;
        -T*)
            echo -e "${ROJO}Error: Timeout invalido. Use -T1, -T2, -T3, -T4, -T5 o -T6${NC}"
            exit 1
            ;;
        *)
            echo -e "${ROJO}Flag desconocido: $1${NC}"
            echo ""
            echo "Uso: $0 [-CU|-US|-EU|-CA] [-D1|-D2|-D3|-D4|-W1|-W2|-W3|-W4] [-T1|-T2|-T3|-T4|-T5|-T6]"
            echo ""
            echo "Regiones disponibles:"
            echo "  -CU    Cuba"
            echo "  -US    Estados Unidos"
            echo "  -EU    Europa"
            echo "  -CA    Canada"
            echo ""
            echo "Ejemplos:"
            echo "  $0 -CU -D1 -T6    # Region CU, DNS Datos 1, Timeout 6s"
            echo "  $0 -US -W2 -T1    # Region US, DNS WiFi 2, Timeout 1s"
            echo "  $0 -EU -D1 -T4    # Region EU, DNS Datos 1, Timeout 4s"
            echo "  $0 -CA -W1 -T3    # Region CA, DNS WiFi 1, Timeout 3s"
            echo "  $0                # Modo interactivo (menu)"
            exit 1
            ;;
    esac
done

# Validaciones
if [ "$MODO_AUTO" = true ] && [ -z "$IP" ]; then
    echo -e "${ROJO}Error: Debes especificar tanto la region (-CU, -US, -EU o -CA) como el DNS (-D1, -D2, -W1, etc.)${NC}"
    exit 1
fi

if [ -n "$IP" ] && [ "$MODO_AUTO" = false ]; then
    echo -e "${ROJO}Error: Debes especificar la region (-CU, -US, -EU o -CA) junto con el DNS${NC}"
    exit 1
fi

# === VERIFICAR BROTLI (silencioso) ===

if [ ! -x "/data/data/com.termux/files/usr/bin/brotli" ]; then
    yes | pkg install -y brotli >/dev/null 2>&1
fi

# === DETECTAR ARQUITECTURA Y DESCARGAR SLIPSTREAM ===

# Detectar si es 32 o 64 bits
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|aarch64|arm64)
        # Arquitectura de 64 bits
        SLIP_URL="https://raw.githubusercontent.com/UserZero075/DownFast/main/slipstream-clientX64"
        BITS="64"
        ;;
    i686|i386|armv7l|armv8l|arm)
        # Arquitectura de 32 bits
        SLIP_URL="https://raw.githubusercontent.com/UserZero075/DownFast/main/slipstream-clientX32"
        BITS="32"
        ;;
    *)
        # Por defecto usar 64 bits
        SLIP_URL="https://raw.githubusercontent.com/UserZero075/DownFast/main/slipstream-clientX64"
        BITS="64 (auto)"
        imprimir_mensaje "WARN" "$AMARILLO" "Arquitectura desconocida ($ARCH), usando version 64 bits"
        ;;
esac

if [ ! -f "slipstream-client" ]; then
    imprimir_mensaje "INFO" "$CYAN" "Descargando slipstream-client ${BITS}-bit para $ARCH..."
    curl -sL -o slipstream-client "$SLIP_URL"
    chmod +x slipstream-client
    imprimir_mensaje "OK" "$VERDE" "Descarga completada"
else
    # Verificar si la versión existente es la correcta
    :
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
        echo -e "${CYAN}+=========================================+${NC}"
        echo -e "${CYAN}|${NC}  ${BLANCO}$prompt${NC}"
        echo -e "${CYAN}+=========================================+${NC}"
        echo ""

        for i in "${!opciones[@]}"; do
            if [ $i -eq $sel ]; then
                echo -e "   ${VERDE}> ${BLANCO}${opciones[$i]}${NC}"
            else
                echo -e "   ${GRIS}  ${opciones[$i]}${NC}"
            fi
        done

        echo ""
        echo -e "${GRIS}-----------------------------------------${NC}"
        echo -e "  ${CYAN}↑↓${NC} Navegar  ${VERDE}Enter${NC} Seleccionar"
        echo -e "${GRIS}-----------------------------------------${NC}"
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

# === FUNCIÓN PARA MATAR INSTANCIAS PREVIAS DEL SCRIPT ===

matar_scripts_previos() {
    local scripts_matados=0
    
    while IFS= read -r linea; do
        local pid=$(echo "$linea" | awk '{print $1}')
        if [ -n "$pid" ] && [ "$pid" != "$MY_PID" ] && [ "$pid" != "$$" ]; then
            kill -9 "$pid" 2>/dev/null
            ((scripts_matados++))
        fi
    done < <(pgrep -af "$SCRIPT_NAME" 2>/dev/null | grep -v "^$MY_PID ")
    
    while IFS= read -r linea; do
        local pid=$(echo "$linea" | awk '{print $1}')
        if [ -n "$pid" ] && [ "$pid" != "$MY_PID" ] && [ "$pid" != "$$" ]; then
            kill -9 "$pid" 2>/dev/null
            ((scripts_matados++))
        fi
    done < <(pgrep -af "slipstream.*auto" 2>/dev/null | grep -v "^$MY_PID ")
    
    return $scripts_matados
}

# === LIMPIAR PROCESOS SLIPSTREAM ===

limpiar_slipstream() {
    local procesos_matados=0
    
    if pgrep -f "slipstream-client" > /dev/null 2>&1; then
        pkill -9 -f "slipstream-client" 2>/dev/null
        procesos_matados=1
    fi
    
    return $procesos_matados
}

# === LIMPIAR PUERTO 5201 ===

limpiar_puerto_5201() {
    if command -v ss > /dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":5201 "; then
            local puerto_pid=$(ss -tulnp 2>/dev/null | grep ":5201 " | grep -oP 'pid=\K[0-9]+' | head -1)
            if [ -n "$puerto_pid" ]; then
                kill -9 "$puerto_pid" 2>/dev/null
                return 0
            fi
        fi
    fi
    return 1
}

# === MATAR PROCESOS TAIL HUÉRFANOS ===

matar_tails_huerfanos() {
    pkill -9 -f "tail.*slipstream" 2>/dev/null
}

# === VERIFICAR SI ES LOG DE DEBUG ===

es_log_debug() {
    local line="$1"
    
    if [[ "$line" =~ ^\[[0-9]+:[0-9]+\][[:space:]]*(wakeup|activate|raw[[:space:]]bytes|recv-\>quic_send|disactivate|quic_send-\>recv|send|recv) ]]; then
        return 0
    fi
    
    if [[ "$line" =~ ^\[[0-9]+:[0-9]+\][[:space:]]*$ ]]; then
        return 0
    fi
    
    if [[ "$line" =~ \\x[0-9a-fA-F]{2} ]]; then
        return 0
    fi
    
    if [ ${#line} -lt 3 ]; then
        return 0
    fi
    
    local special_count=$(echo "$line" | grep -o '[^a-zA-Z0-9 :.,/\-_()[\]]' | wc -l)
    local total_chars=${#line}
    
    if [ "$total_chars" -gt 0 ]; then
        local ratio=$((special_count * 100 / total_chars))
        if [ "$ratio" -gt 50 ]; then
            return 0
        fi
    fi
    
    return 1
}

# === FUNCIÓN PARA COLORIZAR LOGS ===

colorizar_linea() {
    local line="$1"
    case "$line" in
        "Starting connection to "*)
            echo -e "${GRIS}${line}${NC}"
            ;;
        "Initial connection ID: "*)
            echo -e "${GRIS}${line}${NC}"
            ;;
        "Listening on port "*)
            echo -e "${GRIS}${line}${NC}"
            ;;
        "Connection completed, almost ready.")
            echo -e "${GRIS}${line}${NC}"
            ;;
        "Connection confirmed.")
            echo -e "${VERDE}${SYM_CHECK} ${line}${NC}"
            ;;
        "Connection closed.")
            echo -e "${ROJO}${SYM_ERROR} ${line}${NC}"
            ;;
        *"accept() failed: Permission denied"*)
            echo -e "${ROJO}${SYM_ERROR} ${line}${NC}"
            ;;
        *)
            echo "$line"
            ;;
    esac
}

# === CALCULAR ESPERA HASTA SEGUNDO :05 DEL PRÓXIMO MINUTO ===

calcular_espera_hasta_05() {
    local segundo=$(date +%S)
    segundo=$((10#$segundo))
    
    if [ "$segundo" -lt 5 ]; then
        # Estamos antes del :05 de este minuto, esperar lo que falta
        echo $((5 - segundo))
    else
        # Ya pasó :05, esperar hasta :05 del próximo minuto
        echo $((65 - segundo))
    fi
}

# === FUNCIÓN PARA FORMATEAR TIEMPO TRANSCURRIDO ===
formatear_tiempo() {
    local segundos=$1
    
    if [ "$segundos" -lt 60 ]; then
        echo "${segundos}s"
    elif [ "$segundos" -lt 3600 ]; then
        local mins=$((segundos / 60))
        local secs=$((segundos % 60))
        echo "${mins}m ${secs}s"
    else
        local horas=$((segundos / 3600))
        local mins=$(((segundos % 3600) / 60))
        echo "${horas}h ${mins}m"
    fi
}

SLIP_PID=""
MONITOR_PID=""
WATCHDOG_PID=""
RETRY_COUNT=0
MAX_RETRIES=2
RETRY_SIGNAL_FILE=""

# === ARCHIVOS PARA MONITOREO ===
LOG_DIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp"
RAW_BYTE_TS_FILE="$LOG_DIR/slipstream_rawbyte_ts_$$"
RAW_BYTE_MONITOR_FLAG="$LOG_DIR/slipstream_monitor_flag_$$"
RAW_BYTE_TRIGGER_RESTART="$LOG_DIR/slipstream_trigger_restart_$$"
ACCEPT_ERROR_TRIGGER="$LOG_DIR/slipstream_accept_error_$$"
TIMEOUT_CONFIG_FILE="$LOG_DIR/slipstream_timeout_$$"

cleanup() {
    echo ""
    echo -e "${AMARILLO}${SYM_STOP}  [$(date '+%H:%M:%S')] Deteniendo slipstream...${NC}"
    
    if [ -n "$WATCHDOG_PID" ] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
        kill "$WATCHDOG_PID" 2>/dev/null
        wait "$WATCHDOG_PID" 2>/dev/null
    fi
    
    if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null
        wait "$MONITOR_PID" 2>/dev/null
    fi
    
    pkill -9 -f "slipstream-client" 2>/dev/null
    
    rm -f "$RETRY_SIGNAL_FILE" 2>/dev/null
    rm -f "$LOCK_FILE" 2>/dev/null
    rm -f "$RAW_BYTE_TS_FILE" 2>/dev/null
    rm -f "$RAW_BYTE_MONITOR_FLAG" 2>/dev/null
    rm -f "$RAW_BYTE_TRIGGER_RESTART" 2>/dev/null
    rm -f "$ACCEPT_ERROR_TRIGGER" 2>/dev/null
    rm -f "$TIMEOUT_CONFIG_FILE" 2>/dev/null
    
    termux-wake-unlock 2>/dev/null
    echo -e "${VERDE}${SYM_CHECK} [$(date '+%H:%M:%S')] Terminado correctamente.${NC}"
    echo ""
    exit 0
}

trap cleanup SIGINT SIGTERM

# === SELECCIÓN INTERACTIVA ===

if [ "$MODO_AUTO" = false ]; then
    sleep 0.5

    menu_flechas "Que region desea?" "CU (Cuba)" "US (Estados Unidos)" "EU (Europa)" "CA (Canada)"
    case "$SELECCION_GLOBAL" in
        "CU (Cuba)")
            REGION="CU"
            DOMAIN="$CU"
            ;;
        "US (Estados Unidos)")
            REGION="US"
            DOMAIN="$US"
            ;;
        "EU (Europa)")
            REGION="EU"
            DOMAIN="$EU"
            ;;
        "CA (Canada)")
            REGION="CA"
            DOMAIN="$CA"
            ;;
    esac

    menu_flechas "Tipo de conexion?" "Datos moviles" "WiFi"
    TIPO_RED="$SELECCION_GLOBAL"
    if [ "$TIPO_RED" = "Datos moviles" ]; then
        menu_flechas "IP del resolver?" "$D1" "$D2" "$D3" "$D4"
    else
        menu_flechas "IP del resolver?" "$W1" "$W2" "$W3" "$W4"
    fi
    IP="$SELECCION_GLOBAL"

    # === MENÚ DE TIMEOUT ===
    menu_flechas "Elija el Timeout esperado" "6 segundos" "5 segundos" "4 segundos" "3 segundos" "2 segundos" "1 segundo"
    case "$SELECCION_GLOBAL" in
        "6 segundos") TIMEOUT_RAW_BYTES=6 ;;
        "5 segundos") TIMEOUT_RAW_BYTES=5 ;;
        "4 segundos") TIMEOUT_RAW_BYTES=4 ;;
        "3 segundos") TIMEOUT_RAW_BYTES=3 ;;
        "2 segundos") TIMEOUT_RAW_BYTES=2 ;;
        "1 segundo") TIMEOUT_RAW_BYTES=1 ;;
    esac
fi

# === CREAR ARCHIVO DE LOG ===

mkdir -p "$LOG_DIR" 2>/dev/null
PIPE_PATH="$LOG_DIR/slipstream.log"
RETRY_SIGNAL_FILE="$LOG_DIR/slipstream_retry_$$"

# Guardar timeout en archivo para que el watchdog lo lea
echo "$TIMEOUT_RAW_BYTES" > "$TIMEOUT_CONFIG_FILE"

# Limpiar log anterior
> "$PIPE_PATH"

# ===================================================================
# === PANTALLA PRINCIPAL ===
# ===================================================================

clear
echo ""
echo -e "${MAGENTA}+===============================================+${NC}"
echo -e "${MAGENTA}|${NC}  ${BLANCO}${SYM_ROCKET} SLIPSTREAM DEVFAST ${MAGENTA}v2.0${NC}         ${MAGENTA}|${NC}"
echo -e "${MAGENTA}+===============================================+${NC}"
echo ""
echo -e "${CYAN}${SYM_CONFIG} Configuracion:${NC}"
echo -e "  ${GRIS}+-${NC} ${BLANCO}Region:${NC}   ${VERDE}$REGION${NC}"
echo -e "  ${GRIS}|-${NC} ${BLANCO}Dominio:${NC}  ${CYAN}$DOMAIN${NC}"
echo -e "  ${GRIS}|-${NC} ${BLANCO}Resolver:${NC} ${AMARILLO}$IP${NC}"
echo -e "  ${GRIS}|-${NC} ${BLANCO}Timeout:${NC}  ${MAGENTA}${TIMEOUT_RAW_BYTES}s${NC}"
if [ "$MODO_AUTO" = true ]; then
    echo -e "  ${GRIS}+-${NC} ${BLANCO}Modo:${NC}     ${AMARILLO}Automatico${NC}"
else
    echo -e "  ${GRIS}+-${NC} ${BLANCO}Modo:${NC}     ${VERDE}Interactivo${NC}"
fi
echo ""
echo -e "${GRIS}----------------------------------------------${NC}"
echo -e "${CYAN}${SYM_INFO} Para ver todos los logs (incluyendo debug):${NC}"
echo -e "  ${VERDE}>${NC} Abre otra ventana de Termux"
echo -e "  ${VERDE}>${NC} Ejecuta: ${BLANCO}tail -f $PIPE_PATH${NC}"
echo -e "${GRIS}----------------------------------------------${NC}"
echo ""

# ===================================================================
# === LIMPIEZA COMPLETA DE PROCESOS ZOMBIES ===
# ===================================================================

echo -e "${CYAN}${SYM_SEARCH} Verificando procesos previos...${NC}"
echo ""

ALGO_MATADO=false

echo -e "  ${GRIS}|-${NC} Buscando scripts duplicados..."
SCRIPTS_ANTES=$(pgrep -af "$SCRIPT_NAME" 2>/dev/null | grep -v "^$MY_PID " | wc -l)
if [ "$SCRIPTS_ANTES" -gt 0 ]; then
    matar_scripts_previos
    ALGO_MATADO=true
    echo -e "  ${GRIS}|  ${NC}${AMARILLO}${SYM_KILL} Terminadas $SCRIPTS_ANTES instancia(s) del script${NC}"
else
    echo -e "  ${GRIS}|  ${NC}${VERDE}${SYM_CHECK} Sin scripts duplicados${NC}"
fi

echo -e "  ${GRIS}|-${NC} Buscando slipstream-client..."
if pgrep -f "slipstream-client" > /dev/null 2>&1; then
    SLIP_PIDS=$(pgrep -f "slipstream-client" 2>/dev/null | tr '\n' ' ')
    pkill -9 -f "slipstream-client" 2>/dev/null
    ALGO_MATADO=true
    echo -e "  ${GRIS}|  ${NC}${AMARILLO}${SYM_KILL} Terminados PIDs: ${SLIP_PIDS}${NC}"
else
    echo -e "  ${GRIS}|  ${NC}${VERDE}${SYM_CHECK} Sin procesos slipstream-client${NC}"
fi

echo -e "  ${GRIS}|-${NC} Buscando tails huerfanos..."
TAILS_ANTES=$(pgrep -af "tail.*slipstream" 2>/dev/null | wc -l)
if [ "$TAILS_ANTES" -gt 0 ]; then
    matar_tails_huerfanos
    ALGO_MATADO=true
    echo -e "  ${GRIS}|  ${NC}${AMARILLO}${SYM_KILL} Terminados $TAILS_ANTES tail(s)${NC}"
else
    echo -e "  ${GRIS}|  ${NC}${VERDE}${SYM_CHECK} Sin tails huerfanos${NC}"
fi

echo -e "  ${GRIS}+-${NC} Verificando puerto 5201..."
if limpiar_puerto_5201; then
    ALGO_MATADO=true
    echo -e "     ${AMARILLO}${SYM_KILL} Puerto 5201 liberado${NC}"
else
    echo -e "     ${VERDE}${SYM_CHECK} Puerto 5201 libre${NC}"
fi

if [ "$ALGO_MATADO" = true ]; then
    echo ""
    echo -e "${AMARILLO}${SYM_CLOCK} Esperando 3 segundos para liberar recursos...${NC}"
    sleep 3
fi

echo ""
echo -e "${CYAN}${SYM_CLEAN} Estado final de procesos:${NC}"

PROCESOS_SLIP=$(pgrep -af slipstream 2>/dev/null | grep -v "^$MY_PID ")

if [ -n "$PROCESOS_SLIP" ]; then
    echo -e "${MAGENTA}+- Procesos slipstream encontrados:${NC}"
    while IFS= read -r linea; do
        echo -e "${MAGENTA}|  ${linea}${NC}"
    done <<< "$PROCESOS_SLIP"
    echo -e "${MAGENTA}+---------------------------------${NC}"
    echo ""
    echo -e "${ROJO}${SYM_WARN} ADVERTENCIA: Aun hay procesos activos.${NC}"
    echo -e "${AMARILLO}   Considera forzar el cierre de Termux si hay problemas.${NC}"
else
    echo -e "${VERDE}${SYM_CHECK} Sin procesos zombies - Sistema limpio${NC}"
fi

echo "$MY_PID" > "$LOCK_FILE"

echo ""
echo -e "${GRIS}----------------------------------------------${NC}"
echo ""

# === FUNCIÓN WATCHDOG PARA MONITOREAR RAW BYTES ===

iniciar_watchdog() {
    (
        ULTIMO_STATUS_TS=0
        STATUS_INTERVAL=30
        CHECK_INTERVAL=1
        
        while true; do
            if [ -f "$TIMEOUT_CONFIG_FILE" ]; then
                CURRENT_TIMEOUT=$(cat "$TIMEOUT_CONFIG_FILE" 2>/dev/null)
                if [ -z "$CURRENT_TIMEOUT" ]; then
                    CURRENT_TIMEOUT=6
                fi
            else
                CURRENT_TIMEOUT=6
            fi
            
            if [ ! -f "$RAW_BYTE_MONITOR_FLAG" ]; then
                sleep "$CHECK_INTERVAL"
                continue
            fi
            
            if [ -f "$RAW_BYTE_TS_FILE" ]; then
                ULTIMO_RAW_TS=$(cat "$RAW_BYTE_TS_FILE" 2>/dev/null)
                if [ -z "$ULTIMO_RAW_TS" ]; then
                    sleep "$CHECK_INTERVAL"
                    continue
                fi
                
                AHORA=$(date +%s)
                TIEMPO_SIN_RAW=$((AHORA - ULTIMO_RAW_TS))
                
                if [ "$TIEMPO_SIN_RAW" -gt "$CURRENT_TIMEOUT" ]; then
                    TIEMPO_FORMATEADO=$(formatear_tiempo "$TIEMPO_SIN_RAW")
                    echo -e "${ROJO}${SYM_DEAD} [$(date '+%H:%M:%S')] Tunel caido, sin conexion hace ${TIEMPO_FORMATEADO}, reiniciando...${NC}"
                    
                    echo "RESTART_NEEDED" > "$RAW_BYTE_TRIGGER_RESTART"
                    
                    rm -f "$RAW_BYTE_MONITOR_FLAG"
                    
                    sleep 1
                    continue
                fi
                
                if [ "$((AHORA - ULTIMO_STATUS_TS))" -ge "$STATUS_INTERVAL" ]; then
                    TIEMPO_FORMATEADO=$(formatear_tiempo "$TIEMPO_SIN_RAW")
                    echo -e "${VERDE}${SYM_PULSE} [$(date '+%H:%M:%S')] Tunel operativo, ultima conexion hace ${TIEMPO_FORMATEADO}${NC}"
                    ULTIMO_STATUS_TS=$AHORA
                fi
            fi
            
            sleep "$CHECK_INTERVAL"
        done
    ) &
    
    WATCHDOG_PID=$!
}

# === FUNCIÓN PARA DETENER SLIPSTREAM Y MONITOR ===

detener_slipstream() {
    # Detener monitoreo de raw bytes
    rm -f "$RAW_BYTE_MONITOR_FLAG"
    rm -f "$RAW_BYTE_TS_FILE"
    rm -f "$RAW_BYTE_TRIGGER_RESTART"
    rm -f "$ACCEPT_ERROR_TRIGGER"
    
    # Detener monitor de logs
    if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null
        wait "$MONITOR_PID" 2>/dev/null
    fi
    
    # Detener slipstream
    if [ -n "$SLIP_PID" ] && kill -0 "$SLIP_PID" 2>/dev/null; then
        kill "$SLIP_PID" 2>/dev/null
        wait "$SLIP_PID" 2>/dev/null
    fi
    
    # Limpiar señales
    > "$RETRY_SIGNAL_FILE" 2>/dev/null
}

# === FUNCIÓN PARA INICIAR SLIPSTREAM ===

iniciar_slipstream() {
    local tmp_log="$1"
    
    # Reiniciar flags de monitoreo
    rm -f "$RAW_BYTE_TS_FILE"
    rm -f "$RAW_BYTE_MONITOR_FLAG"
    rm -f "$RAW_BYTE_TRIGGER_RESTART"
    rm -f "$ACCEPT_ERROR_TRIGGER"
    > "$RETRY_SIGNAL_FILE" 2>/dev/null
    
    # Iniciar slipstream-client en background
    stdbuf -oL -eL ./slipstream-client \
        --tcp-listen-port=5201 \
        --resolver="${IP}:53" \
        --domain="${DOMAIN}" \
        --keep-alive-interval=600 \
        --congestion-control=cubic > "$tmp_log" 2>&1 &
    
    SLIP_PID=$!
    
    # Monitor de logs
    tail -f -n +1 "$tmp_log" 2>/dev/null | while IFS= read -r line; do
        echo "$line" >> "$PIPE_PATH"
        
        # === PRIORIDAD MÁXIMA: Detectar "accept() failed: Permission denied" ===
        if [[ "$line" =~ "accept() failed: Permission denied" ]]; then
            echo "ACCEPT_ERROR" > "$ACCEPT_ERROR_TRIGGER"
        fi
        
        # Detectar "Connection confirmed"
        if [[ "$line" == "Connection confirmed." ]]; then
            echo "CONFIRMED" > "$RETRY_SIGNAL_FILE"
        fi
        
        # Detectar "Connection closed"
        if [[ "$line" == "Connection closed." ]]; then
            echo "CLOSED" >> "$RETRY_SIGNAL_FILE"
        fi
        
        # Detectar raw bytes
        if [[ "$line" =~ raw[[:space:]]bytes: ]]; then
            TIMESTAMP=$(date +%s)
            echo "$TIMESTAMP" > "$RAW_BYTE_TS_FILE"
            
            if [ ! -f "$RAW_BYTE_MONITOR_FLAG" ]; then
                touch "$RAW_BYTE_MONITOR_FLAG"
            fi
        fi
        
        # Mostrar solo logs no-debug
        if ! es_log_debug "$line"; then
            colorizar_linea "$line"
        fi
    done &
    
    MONITOR_PID=$!
}

# === INICIAR WATCHDOG ===
iniciar_watchdog

# === LOOP PRINCIPAL ===

CHECK_EVERY=0.5  # Reducido de 1 a 0.5 para detección más rápida
RETRY_DELAY=5
TMP_LOG="$LOG_DIR/slipstream_temp_$$.log"

while true; do
    # Resetear contador de reintentos al iniciar nuevo ciclo
    RETRY_COUNT=0
    
    # Limpiar archivos temporales
    > "$TMP_LOG"
    > "$RETRY_SIGNAL_FILE"
    
    echo -e "${VERDE}${SYM_ROCKET} [$(date '+%H:%M:%S')] Iniciando slipstream-client...${NC}"
    echo ""

    iniciar_slipstream "$TMP_LOG"

    # Loop de monitoreo
    while true; do
        
        # === PRIORIDAD 1: VERIFICAR ERROR DE ACCEPT() (MÁXIMA PRIORIDAD) ===
        if [ -f "$ACCEPT_ERROR_TRIGGER" ]; then
            rm -f "$ACCEPT_ERROR_TRIGGER"
            
            echo ""
            echo -e "${ROJO}${SYM_ERROR} [$(date '+%H:%M:%S')] Error de permisos detectado (accept() failed), reiniciando inmediatamente...${NC}"
            
            detener_slipstream
            
            sleep "$RETRY_DELAY"
            
            > "$TMP_LOG"
            RETRY_COUNT=0
            
            iniciar_slipstream "$TMP_LOG"
            echo -e "${VERDE}${SYM_LINK} [$(date '+%H:%M:%S')] Reinicio por error de permisos completado${NC}"
            echo ""
            
            continue
        fi
        
        # === PRIORIDAD 2: VERIFICAR TÚNEL CAÍDO (RAW BYTES) ===
        if [ -f "$RAW_BYTE_TRIGGER_RESTART" ] && grep -q "RESTART_NEEDED" "$RAW_BYTE_TRIGGER_RESTART" 2>/dev/null; then
            rm -f "$RAW_BYTE_TRIGGER_RESTART"
            
            detener_slipstream
            
            sleep "$RETRY_DELAY"
            
            > "$TMP_LOG"
            RETRY_COUNT=0
            
            iniciar_slipstream "$TMP_LOG"
            echo -e "${VERDE}${SYM_LINK} [$(date '+%H:%M:%S')] Reinicio por tunel caido completado${NC}"
            echo ""
            
            continue
        fi
        
        # === PRIORIDAD 3: VERIFICAR "CONNECTION CLOSED" ===
        if [ -f "$RETRY_SIGNAL_FILE" ] && grep -q "CLOSED" "$RETRY_SIGNAL_FILE" 2>/dev/null; then
            # Limpiar la señal
            > "$RETRY_SIGNAL_FILE"
            
            if [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; then
                RETRY_COUNT=$((RETRY_COUNT + 1))
                echo ""
                echo -e "${AMARILLO}${SYM_WARN} [$(date '+%H:%M:%S')] Conexion cerrada. Esperando ${RETRY_DELAY}s antes de reintentar... (${RETRY_COUNT}/${MAX_RETRIES})${NC}"
                
                detener_slipstream
                
                sleep "$RETRY_DELAY"
                
                > "$TMP_LOG"
                
                iniciar_slipstream "$TMP_LOG"
                echo -e "${VERDE}${SYM_LINK} [$(date '+%H:%M:%S')] Reintento ${RETRY_COUNT} iniciado${NC}"
                echo ""
                
            else
                # Se alcanzó el máximo de reintentos, esperar hasta :05
                echo ""
                
                espera_05=$(calcular_espera_hasta_05)
                
                echo -e "${ROJO}${SYM_ERROR} [$(date '+%H:%M:%S')] Maximo de reintentos alcanzado (${MAX_RETRIES})${NC}"
                echo -e "${AMARILLO}${SYM_WAIT} Esperando ${BLANCO}${espera_05}s${AMARILLO} para reconectar automaticamente...${NC}"
                
                detener_slipstream
                
                sleep "$espera_05"
                
                # Resetear todo para nuevo ciclo
                RETRY_COUNT=0
                > "$TMP_LOG"
                > "$RETRY_SIGNAL_FILE"
                
                echo ""
                echo -e "${VERDE}${SYM_ROCKET} [$(date '+%H:%M:%S')] Reconectando automaticamente...${NC}"
                echo ""
                
                iniciar_slipstream "$TMP_LOG"
            fi
            
            continue
        fi
        
        # === RESETEAR CONTADOR SI HAY CONEXIÓN CONFIRMADA ===
        if [ -f "$RETRY_SIGNAL_FILE" ] && grep -q "CONFIRMED" "$RETRY_SIGNAL_FILE" 2>/dev/null; then
            RETRY_COUNT=0
            > "$RETRY_SIGNAL_FILE"
        fi
        
        # === PRIORIDAD 4: VERIFICAR SI SLIPSTREAM CRASHEÓ ===
        if ! kill -0 "$SLIP_PID" 2>/dev/null; then
            # Verificar que no sea por un CLOSED que ya estamos manejando
            if [ ! -f "$RETRY_SIGNAL_FILE" ] || ! grep -q "CLOSED" "$RETRY_SIGNAL_FILE" 2>/dev/null; then
                echo ""
                echo -e "${ROJO}${SYM_SKULL} [$(date '+%H:%M:%S')] slipstream-client crasheo. Reconectando...${NC}"
                
                detener_slipstream
                
                sleep "$RETRY_DELAY"

                > "$TMP_LOG"
                RETRY_COUNT=0

                iniciar_slipstream "$TMP_LOG"
                
                echo -e "${VERDE}${SYM_LINK} [$(date '+%H:%M:%S')] Reconexion por crash iniciada (PID: $SLIP_PID)${NC}"
                echo ""
            fi
        fi
        
        sleep "$CHECK_EVERY"
    done
done
