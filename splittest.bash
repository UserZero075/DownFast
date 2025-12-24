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
NC='\033[0m'

imprimir_mensaje() { echo -e "${2}[${1}] ${3}${NC}"; }

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
  echo -e "${ROJO}Error: Debes especificar región y DNS${NC}"
  exit 1
fi
if [ -n "$IP" ] && [ "$MODO_AUTO" = false ]; then
  echo -e "${ROJO}Error: Debes especificar región junto con el DNS${NC}"
  exit 1
fi

# === BROTLI ===
echo ""
imprimir_mensaje "INFO" "$CYAN" "Verificando dependencias..."
if [ -x "/data/data/com.termux/files/usr/bin/brotli" ]; then
  imprimir_mensaje "OK" "$VERDE" "brotli ✓"
else
  imprimir_mensaje "INFO" "$AMARILLO" "Instalando brotli..."
  yes | pkg install -y brotli 2>/dev/null
  [ -x "/data/data/com.termux/files/usr/bin/brotli" ] && imprimir_mensaje "OK" "$VERDE" "brotli ✓" || imprimir_mensaje "ERROR" "$ROJO" "brotli falló"
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

# === MENÚ CON FLECHAS ===
SELECCION_GLOBAL=""
menu_flechas() {
  local prompt="$1"; shift
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
        ((sel--)); [ $sel -lt 0 ] && sel=$((total-1)); mostrar
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
  local ahora=$((minuto*60 + segundo))
  local objetivos=(22 322 622 922 1222 1522 1822 2122 2422 2722 3022 3322)
  for objetivo in "${objetivos[@]}"; do
    if [ "$ahora" -lt "$objetivo" ]; then
      echo $((objetivo - ahora)); return
    fi
  done
  echo $((3600 + 22 - ahora))
}

# ================== WATCHDOG ==================
CHECK_EVERY=2
RETRY_DELAY=2

RAW_TIMEOUT=15
RAW_CHECK_EVERY=1

TMPBASE="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
mkdir -p "$TMPBASE" 2>/dev/null

LAST_RAW_FILE="$TMPBASE/slip_last_raw.$$"

PID=""
PIPE_PID=""
WATCH_PID=""

cleanup() {
  echo ""
  echo "[$(date '+%H:%M:%S')] Deteniendo..."
  [ -n "$PID" ] && kill "$PID" 2>/dev/null
  [ -n "$PIPE_PID" ] && kill "$PIPE_PID" 2>/dev/null
  [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null
  rm -f "$LAST_RAW_FILE" 2>/dev/null
  termux-wake-unlock 2>/dev/null
  echo "[$(date '+%H:%M:%S')] Terminado."
  exit 0
}
trap cleanup SIGINT SIGTERM

# Watcher binario-safe SIN Python: lee bloques y busca "raw bytes:" aunque no haya \n
watch_rawbytes_blocks() {
  local last_file="$1"
  local bs=4096
  while true; do
    # Lee un bloque y lo duplica:
    # - una rama busca "raw bytes:" (grep -a trabaja con binario)
    # - la otra cuenta bytes para saber si hubo EOF
    local n
    n=$(
      dd bs=$bs count=1 2>/dev/null \
      | tee >(LC_ALL=C grep -a -q 'raw bytes:' && date +%s > "$last_file") \
      | wc -c
    )
    [ "${n:-0}" -eq 0 ] && break
  done
}

# === SELECCIÓN ===
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

# === UI ===
clear
echo "========================================="
echo "   SLIPSTREAM AUTO-RESTART v0.5"
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
  end_ts=$(( $(date +%s) + espera ))

  echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client..."
  echo "[$(date '+%H:%M:%S')] Próximo reinicio en ${espera}s (~$((espera/60))min)"
  echo ""

  # init timestamp
  date +%s > "$LAST_RAW_FILE" 2>/dev/null || true

  # Armamos el comando
  CMD="./slipstream-client --tcp-listen-port=5201 --resolver=${IP}:53 --domain=${DOMAIN} --keep-alive-interval=120 --congestion-control=cubic"

  # Ejecutar con PTY si existe "script" (evita buffering y preserva log nativo)
  if command -v script >/dev/null 2>&1; then
    # El output va a stdout como si fuese TTY
    ( script -q -c "$CMD" /dev/null ) 2>&1 \
      | tee >(watch_rawbytes_blocks "$LAST_RAW_FILE") &
  else
    # fallback (puede bufferizar si el binario lo hace)
    ( eval "$CMD" ) 2>&1 \
      | tee >(watch_rawbytes_blocks "$LAST_RAW_FILE") &
  fi
  PIPE_PID=$!

  # Obtener PID real del slipstream-client (mejor esfuerzo)
  PID=$(pgrep -n -f "slipstream-client.*--tcp-listen-port=5201.*--resolver=${IP}:53.*--domain=${DOMAIN}" 2>/dev/null)
  [ -z "$PID" ] && PID="$PIPE_PID"

  # Loop hasta el reinicio programado o evento watchdog
  while [ "$(date +%s)" -lt "$end_ts" ]; do
    if ! kill -0 "$PID" 2>/dev/null; then
      echo ""
      echo "[$(date '+%H:%M:%S')] slipstream-client se cayó. Reconectando..."
      kill "$PIPE_PID" 2>/dev/null
      sleep "$RETRY_DELAY"
      break
    fi

    now=$(date +%s)
    last=$(cat "$LAST_RAW_FILE" 2>/dev/null || echo "$now")  # fallback seguro
    if [ $((now - last)) -gt "$RAW_TIMEOUT" ]; then
      echo ""
      echo "[$(date '+%H:%M:%S')] Sin raw bytes hace $((now-last))s (> ${RAW_TIMEOUT}s). Reiniciando..."
      kill "$PID" 2>/dev/null
      kill "$PIPE_PID" 2>/dev/null
      sleep "$RETRY_DELAY"
      break
    fi

    sleep "$RAW_CHECK_EVERY"
  done

  echo ""
  echo "[$(date '+%H:%M:%S')] Reiniciando slipstream-client..."
  kill "$PID" 2>/dev/null
  kill "$PIPE_PID" 2>/dev/null
done
