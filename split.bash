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

# Colores
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

imprimir_mensaje() {
    echo -e "${2}[${1}] ${3}${NC}"
}

paquete_instalado() {
    pkg list-installed 2>/dev/null | grep -q "^$1/"
}

# === VERIFICACIONES ===

if ! paquete_instalado wget; then
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando wget..."
    pkg install wget -y
else
    imprimir_mensaje "OK" "$VERDE" "wget ya instalado"
fi

if [ ! -f "slipstream-client" ]; then
    imprimir_mensaje "INFO" "$AMARILLO" "Descargando slipstream-client..."
    wget https://raw.githubusercontent.com/Mahboub-power-is-back/quic_over_dns/main/slipstream-client
    chmod +x slipstream-client
else
    imprimir_mensaje "OK" "$VERDE" "slipstream-client ya existe"
fi

if ! paquete_instalado openssl; then
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando openssl..."
    pkg install openssl -y
else
    imprimir_mensaje "OK" "$VERDE" "openssl ya instalado"
fi

if ! paquete_instalado dos2unix; then
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando dos2unix..."
    pkg install dos2unix -y
else
    imprimir_mensaje "OK" "$VERDE" "dos2unix ya instalado"
fi

if ! paquete_instalado brotli; then
    imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
    pkg install brotli -y
else
    imprimir_mensaje "OK" "$VERDE" "brotli ya instalado"
fi

# === MENÚ CON FLECHAS (SIMPLE) ===

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
        # Leer un caracter
        IFS= read -rsn1 key
        
        # Si es escape, leer más
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            if [[ "$key" == "[A" ]]; then
                # Arriba
                ((sel--))
                [ $sel -lt 0 ] && sel=$((total - 1))
                mostrar
            elif [[ "$key" == "[B" ]]; then
                # Abajo
                ((sel++))
                [ $sel -ge $total ] && sel=0
                mostrar
            fi
        elif [[ "$key" == "" ]]; then
            # Enter
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
    echo "[$(date '+%H:%M:%S')] Terminado."
    exit 0
}

trap cleanup SIGINT SIGTERM

# === SELECCIÓN ===

sleep 1

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
