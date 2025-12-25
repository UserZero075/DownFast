#!/bin/bash

# ==========================================================
# SLIPSTREAM AUTO-RESTART v1.3
# - FIFO + detección CONFIRMED / CLOSED / RAW
# - Log se limpia por sesión
# - CLOSED: reintenta 2 veces por ciclo y luego espera al reinicio programado
# - SSH health-check ESTRICTO cada HEALTH_CHECK_INTERVAL (evita “martillar” el túnel)
# - Mensajes en tiempo real (sin rate-limit artificial)
# ==========================================================

# ------------------ CONFIG ------------------
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

CHECK_EVERY=2                 # loop interno (sólo para vigilar proceso/eventos)
HEALTH_CHECK_INTERVAL=10      # SSH check estricto cada 10s
HEALTH_CHECK_DELAY=8          # espera inicial tras iniciar cliente
RETRY_DELAY=3                 # delay para relanzar tras fallo

CLOSED_RECONNECT_DELAY=10
CLOSED_MAX_RETRIES=2
# --------------------------------------------

export DEBIAN_FRONTEND=noninteractive
termux-wake-lock 2>/dev/null

# Colores
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------ ARGS ------------------
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
    *) echo "Uso: $0 -CU|-US -D1|-D2|-D3|-D4|-W1|-W2|-W3|-W4"; exit 1 ;;
  esac
done

if [ "$MODO_AUTO" = true ] && [ -z "$IP" ]; then
  echo -e "${ROJO}Error: Debes especificar región (-CU/-US) y DNS (-D1, -D2, -W1, etc.)${NC}"
  exit 1
fi

# ------------------ SSH CHECK ------------------
verificar_tunel() {
  ssh -p 5201 \
    -o BatchMode=yes \
    -o NumberOfPasswordPrompts=0 \
    -o PasswordAuthentication=no \
    -o KbdInteractiveAuthentication=no \
    -o ChallengeResponseAuthentication=no \
    -o PubkeyAuthentication=no \
    -o PreferredAuthentications=none \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=8 \
    -o ConnectionAttempts=1 \
    -o LogLevel=ERROR \
    127.0.0.1 exit 2>&1 | grep -q "Permission denied"
}

# ------------------ TIME ------------------
calcular_espera() {
  local m=$(date +%M) s=$(date +%S)
  m=$((10#$m)); s=$((10#$s))
  local now=$((m*60+s))
  local slots=(22 322 622 922 1222 1522 1822 2122 2422 2722 3022 3322)
  for t in "${slots[@]}"; do
    [ "$now" -lt "$t" ] && { echo $((t-now)); return; }
  done
  echo $((3600+22-now))
}

# ------------------ LOG / STATE ------------------
FULL_LOG="$HOME/slipstream-full.log"
LOG_PIPE=""
PID=""
MON_PID=""

STATE_DIR="$HOME/.slip_state"
mkdir -p "$STATE_DIR"

F_CONF="$STATE_DIR/confirmed"
F_RAW="$STATE_DIR/raw"
F_CLOSED="$STATE_DIR/closed"

reset_state() {
  echo 0 >"$F_CONF"
  echo 0 >"$F_RAW"
  echo 0 >"$F_CLOSED"
}

monitor_fifo() {
  while IFS= read -r line; do
    printf '%s\n' "$line" >>"$FULL_LOG"

    echo "$line" | grep -qi 'Connection confirmed' && echo 1 >"$F_CONF"
    echo "$line" | grep -qi 'raw bytes' && echo 1 >"$F_RAW"
    echo "$line" | grep -qi 'Connection closed' && echo 1 >"$F_CLOSED"

    echo "$line" | grep -Eai \
      'Starting connection|Initial connection ID|Listening on port|Connection confirmed|Connection closed'
  done <"$LOG_PIPE"
}

start_slipstream() {
  reset_state
  : >"$FULL_LOG"  # limpiar log por sesión

  LOG_PIPE="$(mktemp -u "$HOME/slip.pipe.XXXX")"
  mkfifo "$LOG_PIPE" || return 1

  ./slipstream-client \
    --tcp-listen-port=5201 \
    --resolver="${IP}:53" \
    --domain="${DOMAIN}" \
    --keep-alive-interval=120 \
    --congestion-control=cubic \
    >"$LOG_PIPE" 2>&1 &
  PID=$!

  monitor_fifo &
  MON_PID=$!
}

stop_slipstream() {
  # matar procesos si existen
  [ -n "$PID" ] && kill "$PID" 2>/dev/null
  [ -n "$MON_PID" ] && kill "$MON_PID" 2>/dev/null

  wait "$PID" 2>/dev/null
  wait "$MON_PID" 2>/dev/null

  [ -n "$LOG_PIPE" ] && rm -f "$LOG_PIPE" 2>/dev/null

  PID=""; MON_PID=""; LOG_PIPE=""
}

cleanup() {
  echo ""
  echo "[$(date +%H:%M:%S)] Deteniendo..."
  stop_slipstream
  termux-wake-unlock 2>/dev/null
  echo "[$(date +%H:%M:%S)] Terminado."
  exit 0
}
trap cleanup SIGINT SIGTERM

# ------------------ UI ------------------
clear
echo "========================================="
echo "   SLIPSTREAM AUTO-RESTART v1.3"
echo "========================================="
echo "Región:   $REGION"
echo "Dominio:  $DOMAIN"
echo "Resolver: $IP"
echo "Modo:     Automático"
echo "========================================="
echo "Log: $FULL_LOG"
echo ""

# ------------------ MAIN LOOP ------------------
while true; do
  espera=$(calcular_espera)
  end_ts=$(( $(date +%s) + espera ))
  closed_retries=0

  echo "[$(date +%H:%M:%S)] Próximo reinicio en ${espera}s (~$((espera/60))min)"

  while [ "$(date +%s)" -lt "$end_ts" ]; do
    echo "[$(date +%H:%M:%S)] Iniciando slipstream-client..."
    start_slipstream || { echo -e "${ROJO}No se pudo iniciar slipstream-client${NC}"; sleep "$RETRY_DELAY"; continue; }

    # Espera inicial
    sleep "$HEALTH_CHECK_DELAY"

    # Programador estricto para health-check
    next_health_ts=$(( $(date +%s) + HEALTH_CHECK_INTERVAL ))

    while [ "$(date +%s)" -lt "$end_ts" ]; do
      sleep "$CHECK_EVERY"
      now=$(date +%s)

      # 1) Proceso muerto
      if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
        echo -e "[$(date +%H:%M:%S)] ${AMARILLO}Proceso murió. Reconectando...${NC}"
        stop_slipstream
        sleep "$RETRY_DELAY"
        break
      fi

      # 2) Connection closed (máx 2 reintentos por ciclo)
      if [ "$(cat "$F_CLOSED" 2>/dev/null)" = "1" ]; then
        echo 0 >"$F_CLOSED"
        closed_retries=$((closed_retries+1))

        if [ "$closed_retries" -le "$CLOSED_MAX_RETRIES" ]; then
          echo -e "[$(date +%H:%M:%S)] ${AMARILLO}Connection closed. Reintento ${closed_retries}/${CLOSED_MAX_RETRIES} en ${CLOSED_RECONNECT_DELAY}s...${NC}"
          stop_slipstream
          sleep "$CLOSED_RECONNECT_DELAY"
          break
        else
          rem=$((end_ts-now)); [ "$rem" -lt 0 ] && rem=0
          echo -e "[$(date +%H:%M:%S)] ${ROJO}Connection closed repetido.${NC}"
          echo -e "[$(date +%H:%M:%S)] ${AMARILLO}Espere al próximo reinicio en $((rem/60))m $((rem%60))s${NC}"
          stop_slipstream
          sleep "$rem"
          break
        fi
      fi

      # 3) Health-check (estricto cada 10s)
      if [ "$now" -ge "$next_health_ts" ]; then
        next_health_ts=$(( now + HEALTH_CHECK_INTERVAL ))

        if [ "$(cat "$F_CONF" 2>/dev/null)" = "1" ]; then
          if [ "$(cat "$F_RAW" 2>/dev/null)" = "0" ]; then
            echo -e "[$(date +%H:%M:%S)] ${CYAN}Conexión confirmada, pero aún sin tráfico (raw). Omitiendo health-check SSH...${NC}"
          else
            if ! verificar_tunel; then
              echo -e "[$(date +%H:%M:%S)] ${ROJO}Túnel no responde (SSH). Reconectando...${NC}"
              stop_slipstream
              sleep "$RETRY_DELAY"
              break
            else
              echo -e "[$(date +%H:%M:%S)] ${VERDE}Túnel OK${NC}"
            fi
          fi
        fi
      fi
    done

    # Si salimos del while interno, garantizar limpieza del intento
    stop_slipstream
  done

  echo "[$(date +%H:%M:%S)] Reinicio programado..."
done
