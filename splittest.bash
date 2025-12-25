#!/bin/bash

# =========================
#   SLIPSTREAM AUTO-RESTART
#   (Opción B: FIFO + filtro + lógica CONFIRMED/CLOSED/RAW)
#   + Limpieza del log por sesión
# =========================

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
  echo -e "${ROJO}Error: Debes especificar región (-CU/-US) y DNS (-D1, -D2, -W1, etc.)${NC}"
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
  if echo "$output" | grep -q "Permission denied"; then
    return 0
  else
    return 1
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

  # Reinicios: cada 5 minutos en el segundo 22
  local objetivos=(22 322 622 922 1222 1522 1822 2122 2422 2722 3022 3322)

  for objetivo in "${objetivos[@]}"; do
    if [ "$ahora" -lt "$objetivo" ]; then
      echo $((objetivo - ahora))
      return
    fi
  done

  echo $((3600 + 22 - ahora))
}

# ================== PARÁMETROS DE MONITOREO ==================
CHECK_EVERY=2              # loop principal
RETRY_DELAY=3              # espera antes de relanzar (si aplica)
HEALTH_CHECK_INTERVAL=10   # cada 10s
HEALTH_CHECK_DELAY=8       # espera inicial antes de evaluar estados
CLOSED_RECONNECT_DELAY=10  # si "Connection closed", esperar 10s y reconectar
# =============================================================

# =========================
#   LOGGING + ESTADO (FIFO)
# =========================
FULL_LOG="$HOME/slipstream-full.log"

# Solo esto se muestra en pantalla desde slipstream-client
SHOW_REGEX='Starting connection to|Initial connection ID|Listening on port|Connection confirmed|Connection closed|Client exit|Signal'

LOG_PIPE=""
PID=""          # PID real del slipstream-client
MON_PID=""      # PID del monitor (lector del FIFO)

# Estado controlado por archivos (seguro entre procesos)
STATE_DIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/slip_state"
mkdir -p "$STATE_DIR"

F_CONF="$STATE_DIR/confirmed"
F_RAW="$STATE_DIR/got_raw"
F_LASTRAW="$STATE_DIR/last_raw_ts"
F_CLOSED="$STATE_DIR/closed_count"
F_SEEN_CLOSED="$STATE_DIR/closed_seen"   # flag para “evento cerrado” reciente

reset_state() {
  echo 0 >"$F_CONF"
  echo 0 >"$F_RAW"
  echo 0 >"$F_LASTRAW"
  echo 0 >"$F_CLOSED"
  echo 0 >"$F_SEEN_CLOSED"
}

get_state_int() {
  local f="$1"
  [ -f "$f" ] || { echo 0; return; }
  local v
  v=$(cat "$f" 2>/dev/null)
  [[ "$v" =~ ^[0-9]+$ ]] || v=0
  echo "$v"
}

monitor_fifo() {
  # Lee línea por línea del FIFO, guarda FULL_LOG, actualiza estado y muestra solo lo filtrado
  while IFS= read -r line; do
    printf '%s\n' "$line" >> "$FULL_LOG"

    # Detectar "raw bytes" para habilitar checks (una vez haya tráfico real)
    if echo "$line" | grep -Eqi 'raw bytes'; then
      echo 1 >"$F_RAW"
      date +%s >"$F_LASTRAW"
    fi

    # Detectar confirmación
    if echo "$line" | grep -Eqi 'Connection confirmed'; then
      echo 1 >"$F_CONF"
    fi

    # Detectar cerrada
    if echo "$line" | grep -Eqi 'Connection closed'; then
      local c
      c=$(get_state_int "$F_CLOSED")
      c=$((c + 1))
      echo "$c" >"$F_CLOSED"
      echo 1 >"$F_SEEN_CLOSED"
    fi

    # Mostrar solo lo que interesa
    if echo "$line" | grep -Eaiq "$SHOW_REGEX"; then
      printf '%s\n' "$line"
    fi
  done < "$LOG_PIPE"
}

start_slipstream() {
  reset_state

  # ======= DETALLE PEDIDO: limpiar el log por sesión =======
  : > "$FULL_LOG"
  # ========================================================

  LOG_PIPE="$(mktemp -u "${TMPDIR:-/data/data/com.termux/files/usr/tmp}/slipstream.pipe.XXXXXX")"
  mkfifo "$LOG_PIPE" || return 1

  # Lanzar slipstream-client (PID real)
  ./slipstream-client \
    --tcp-listen-port=5201 \
    --resolver="${IP}:53" \
    --domain="${DOMAIN}" \
    --keep-alive-interval=120 \
    --congestion-control=cubic \
    >"$LOG_PIPE" 2>&1 &
  PID=$!

  # Monitor del FIFO
  monitor_fifo &
  MON_PID=$!
}

stop_slipstream() {
  # mata cliente
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
  fi

  # mata monitor
  if [ -n "$MON_PID" ] && kill -0 "$MON_PID" 2>/dev/null; then
    kill "$MON_PID" 2>/dev/null
    wait "$MON_PID" 2>/dev/null
  fi

  # limpia fifo
  if [ -n "$LOG_PIPE" ]; then
    rm -f "$LOG_PIPE" 2>/dev/null
    LOG_PIPE=""
  fi

  PID=""
  MON_PID=""
}

cleanup() {
  echo ""
  echo "[$(date '+%H:%M:%S')] Deteniendo..."
  stop_slipstream
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
  if [ "$REGION" = "CU" ]; then DOMAIN="$CU"; else DOMAIN="$US"; fi

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
echo "   SLIPSTREAM AUTO-RESTART v1.0"
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
echo "Log completo (se limpia por sesión): $FULL_LOG"
echo ""

# =========================
#   LOOP PRINCIPAL
# =========================
contador_health=0
msg_omitido_last=0

while true; do
  espera=$(calcular_espera)
  end_ts=$(( $(date +%s) + espera ))

  echo "[$(date '+%H:%M:%S')] Iniciando slipstream-client..."
  echo "[$(date '+%H:%M:%S')] Próximo reinicio programado en ${espera}s (~$((espera/60))min)"
  echo ""

  start_slipstream || {
    echo -e "${ROJO}No se pudo iniciar slipstream-client (FIFO).${NC}"
    sleep "$RETRY_DELAY"
    continue
  }

  contador_health=0
  primera_verificacion=true
  msg_omitido_last=0

  # Vigilar hasta el reinicio programado
  while [ "$(date +%s)" -lt "$end_ts" ]; do
    now=$(date +%s)

    # Si el proceso murió, reiniciar normal
    if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
      echo ""
      echo "[$(date '+%H:%M:%S')] ${AMARILLO}Proceso murió. Reconectando...${NC}"
      stop_slipstream
      sleep "$RETRY_DELAY"
      break
    fi

    # Reaccionar a "Connection closed"
    seen_closed=$(get_state_int "$F_SEEN_CLOSED")
    if [ "$seen_closed" -eq 1 ]; then
      echo 0 >"$F_SEEN_CLOSED"
      closed_count=$(get_state_int "$F_CLOSED")

      if [ "$closed_count" -eq 1 ]; then
        echo ""
        echo "[$(date '+%H:%M:%S')] ${AMARILLO}Connection closed detectado. Reintentando en ${CLOSED_RECONNECT_DELAY}s...${NC}"
        stop_slipstream
        sleep "$CLOSED_RECONNECT_DELAY"
        break
      else
        # Segundo "closed" (o más) dentro del mismo ciclo:
        # No insistir; esperar al reinicio programado.
        restante=$(( end_ts - now ))
        [ "$restante" -lt 0 ] && restante=0
        echo ""
        echo "[$(date '+%H:%M:%S')] ${ROJO}Connection closed repetido.${NC}"
        echo "[$(date '+%H:%M:%S')] ${AMARILLO}Espere al próximo reinicio del server en: ${restante}s (~$((restante/60))min)${NC}"
        stop_slipstream
        sleep "$restante"
        break
      fi
    fi

    # Tick de health
    contador_health=$((contador_health + CHECK_EVERY))

    # Espera inicial antes de considerar checks
    if [ "$primera_verificacion" = true ]; then
      if [ "$contador_health" -ge "$HEALTH_CHECK_DELAY" ]; then
        primera_verificacion=false
        contador_health=0
      fi
    else
      if [ "$contador_health" -ge "$HEALTH_CHECK_INTERVAL" ]; then
        contador_health=0

        confirmed=$(get_state_int "$F_CONF")
        got_raw=$(get_state_int "$F_RAW")

        # Comportamiento pedido:
        # - Solo hacer check SSH si ya hubo "Connection confirmed" Y ya apareció al menos 1 "raw bytes".
        # - Si confirmed=1 pero got_raw=0, omitir check sin reconectar.
        if [ "$confirmed" -eq 1 ] && [ "$got_raw" -eq 0 ]; then
          # Mensaje no-spam: máx 1 cada 30s
          if [ $((now - msg_omitido_last)) -ge 30 ]; then
            echo "[$(date '+%H:%M:%S')] ${CYAN}Conexión confirmada, pero aún sin tráfico (raw). Omitiendo health-check SSH...${NC}"
            msg_omitido_last=$now
          fi
        elif [ "$confirmed" -eq 1 ] && [ "$got_raw" -eq 1 ]; then
          # Ya hay tráfico: health-check normal
          if ! verificar_tunel; then
            echo ""
            echo "[$(date '+%H:%M:%S')] ${ROJO}Túnel no responde (SSH). Reconectando...${NC}"
            stop_slipstream
            sleep "$RETRY_DELAY"
            break
          else
            echo "[$(date '+%H:%M:%S')] ${VERDE}Túnel OK${NC}"
          fi
        else
          # Aún no confirmado: no hacemos checks
          :
        fi
      fi
    fi

    sleep "$CHECK_EVERY"
  done

  echo ""
  echo "[$(date '+%H:%M:%S')] Reinicio programado..."
  stop_slipstream
done
