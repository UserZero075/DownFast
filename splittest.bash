#!/bin/bash

# ==========================================================
# SLIPSTREAM AUTO-RESTART v1.1
# FIFO + detección CONFIRMED / CLOSED / RAW
# Reconexión limpia por SSH caído o proceso muerto
# Log limpio por sesión
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

CHECK_EVERY=2
HEALTH_CHECK_INTERVAL=10
HEALTH_CHECK_DELAY=8
RETRY_DELAY=3

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

# ------------------ SSH CHECK ------------------
verificar_tunel() {
  ssh -p 5201 \
    -o BatchMode=yes \
    -o PasswordAuthentication=no \
    -o KbdInteractiveAuthentication=no \
    -o PubkeyAuthentication=no \
    -o PreferredAuthentications=none \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=8 \
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
    echo "$line" >>"$FULL_LOG"

    echo "$line" | grep -qi 'Connection confirmed' && echo 1 >"$F_CONF"
    echo "$line" | grep -qi 'raw bytes' && echo 1 >"$F_RAW"
    echo "$line" | grep -qi 'Connection closed' && echo 1 >"$F_CLOSED"

    echo "$line" | grep -Eai \
      'Starting connection|Initial connection ID|Listening on port|Connection confirmed|Connection closed'
  done <"$LOG_PIPE"
}

start_slipstream() {
  reset_state
  : >"$FULL_LOG"

  LOG_PIPE="$(mktemp -u "$HOME/slip.pipe.XXXX")"
  mkfifo "$LOG_PIPE"

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
  kill "$PID" "$MON_PID" 2>/dev/null
  wait "$PID" "$MON_PID" 2>/dev/null
  rm -f "$LOG_PIPE"
  PID=""; MON_PID=""
}

trap 'stop_slipstream; termux-wake-unlock; exit' SIGINT SIGTERM

# ------------------ UI ------------------
clear
echo "========================================="
echo "   SLIPSTREAM AUTO-RESTART v1.2"
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
    start_slipstream
    sleep "$HEALTH_CHECK_DELAY"

    while [ "$(date +%s)" -lt "$end_ts" ]; do
      sleep "$CHECK_EVERY"

      # proceso muerto
      if ! kill -0 "$PID" 2>/dev/null; then
        echo -e "[$(date +%H:%M:%S)] ${AMARILLO}Proceso murió. Reconectando...${NC}"
        stop_slipstream
        sleep "$RETRY_DELAY"
        break
      fi

      # connection closed
      if [ "$(cat "$F_CLOSED")" = "1" ]; then
        echo 0 >"$F_CLOSED"
        closed_retries=$((closed_retries+1))

        if [ "$closed_retries" -le "$CLOSED_MAX_RETRIES" ]; then
          echo -e "[$(date +%H:%M:%S)] ${AMARILLO}Connection closed. Reintento ${closed_retries}/${CLOSED_MAX_RETRIES} en ${CLOSED_RECONNECT_DELAY}s...${NC}"
          stop_slipstream
          sleep "$CLOSED_RECONNECT_DELAY"
          break
        else
          rem=$((end_ts-$(date +%s)))
          echo -e "[$(date +%H:%M:%S)] ${ROJO}Connection closed repetido.${NC}"
          echo -e "[$(date +%H:%M:%S)] ${AMARILLO}Espere al próximo reinicio en $((rem/60))m $((rem%60))s${NC}"
          stop_slipstream
          sleep "$rem"
          break
        fi
      fi

      # health check
      if [ "$(cat "$F_CONF")" = "1" ]; then
        if [ "$(cat "$F_RAW")" = "0" ]; then
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
    done
  done

  echo "[$(date +%H:%M:%S)] Reinicio programado..."
done
