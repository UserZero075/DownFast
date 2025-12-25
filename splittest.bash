#!/bin/bash

# ==========================================================
# SLIPSTREAM AUTO-RESTART v2.0  (SIN SSH)
# - FIFO + detección CONFIRMED / CLOSED / RAW
# - Reconexión por "stall" de raw bytes:
#     * Solo aplica si ya hubo raw alguna vez en la sesión
#     * Si pasan RAW_STALL_SECONDS sin nuevos "raw bytes" => reconecta
# - Connection closed:
#     * reintenta hasta CLOSED_MAX_RETRIES por ciclo
#     * luego espera al reinicio programado
# - Log se limpia por sesión
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

CHECK_EVERY=2                 # loop interno
RETRY_DELAY=3                 # delay al relanzar por fallo "normal"

CLOSED_RECONNECT_DELAY=10
CLOSED_MAX_RETRIES=2

RAW_STALL_SECONDS=10          # <-- si no llegan "raw bytes" en >= 10s, reconectar (solo si ya hubo raw)
RAW_STALL_CHECK_EVERY=2       # cada cuánto evaluamos el stall (en segundos)
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
F_LASTRAW="$STATE_DIR/last_raw_ts"
F_CLOSED="$STATE_DIR/closed"

reset_state() {
  echo 0 >"$F_CONF"
  echo 0 >"$F_RAW"
  echo 0 >"$F_LASTRAW"
  echo 0 >"$F_CLOSED"
}

monitor_fifo() {
  while IFS= read -r line; do
    printf '%s\n' "$line" >>"$FULL_LOG"

    if echo "$line" | grep -qi 'Connection confirmed'; then
      echo 1 >"$F_CONF"
    fi

    if echo "$line" | grep -qi 'raw bytes'; then
      echo 1 >"$F_RAW"
      date +%s >"$F_LASTRAW"
    fi

    if echo "$line" | grep -qi 'Connection closed'; then
      echo 1 >"$F_CLOSED"
    fi

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
echo "   SLIPSTREAM AUTO-RESTART v2.0"
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

    # Inicializa marca de tiempo para stall (0 = aún no hubo raw)
    last_stall_check_ts=$(date +%s)

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

      # 2) Connection closed (máx reintentos por ciclo)
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

      # 3) RAW stall check (solo si ya hubo raw)
      #    Revisa cada RAW_STALL_CHECK_EVERY segundos (para no calcular cada tick si no quieres)
      if [ $((now - last_stall_check_ts)) -ge "$RAW_STALL_CHECK_EVERY" ]; then
        last_stall_check_ts=$now

        got_raw=$(cat "$F_RAW" 2>/dev/null || echo 0)
        if [ "$got_raw" = "1" ]; then
          last_raw=$(cat "$F_LASTRAW" 2>/dev/null || echo 0)
          if [ "$last_raw" -gt 0 ]; then
            delta=$((now - last_raw))
            if [ "$delta" -ge "$RAW_STALL_SECONDS" ]; then
              echo -e "[$(date +%H:%M:%S)] ${ROJO}Sin raw bytes hace ${delta}s (>= ${RAW_STALL_SECONDS}s). Reconectando...${NC}"
              stop_slipstream
              sleep "$RETRY_DELAY"
              break
            fi
          fi
        else
          # Si está confirmado pero aún no hay raw, solo informamos (no reconectar)
          if [ "$(cat "$F_CONF" 2>/dev/null)" = "1" ]; then
            echo -e "[$(date +%H:%M:%S)] ${CYAN}Conexión confirmada, esperando tráfico (raw) para habilitar reconexión por stall...${NC}"
          fi
        fi
      fi
    done

    stop_slipstream
  done

  echo "[$(date +%H:%M:%S)] Reinicio programado..."
done
