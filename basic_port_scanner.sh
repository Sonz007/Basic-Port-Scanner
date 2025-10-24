#!/usr/bin/env bash
#
# basic_port_scanner.sh
# Simple TCP port scanner using netcat (nc).
# Usage:
#   ./basic_port_scanner.sh <host> <start_port> <end_port>
# Example:
#   ./basic_port_scanner.sh 192.168.1.10 20 1024

HOST="$1"
START_PORT="$2"
END_PORT="$3"
TIMEOUT=1       # seconds for each connect attempt
CONCURRENCY=200 # how many background jobs at once (tune lower for small machines)

if [[ -z "$HOST" || -z "$START_PORT" || -z "$END_PORT" ]]; then
  echo "Usage: $0 <host> <start_port> <end_port>"
  exit 1
fi

# check netcat availability
if ! command -v nc >/dev/null 2>&1; then
  echo "Error: 'nc' (netcat) is required. Install it (e.g., sudo apt install netcat-openbsd)"
  exit 2
fi

# worker control
active_jobs=0
open_ports=()

scan_port() {
  local port=$1
  # -z : zero-I/O mode (just check), -w timeout, -v verbose
  nc -z -w $TIMEOUT "$HOST" "$port" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "$port"    # port open
  fi
}

export -f scan_port
export HOST TIMEOUT

echo "[*] Scanning $HOST ports $START_PORT..$END_PORT (timeout ${TIMEOUT}s)"

for ((p=START_PORT; p<=END_PORT; p++)); do
  # run scan in background and capture result to temporary file
  (
    res=$(scan_port "$p")
    if [[ -n "$res" ]]; then
      echo "$res"
    fi
  ) &
  ((active_jobs++))

  # throttle concurrency
  if (( active_jobs >= CONCURRENCY )); then
    wait -n   # wait for any job to finish (requires bash 4.3+)
    # recompute active jobs (simple approach)
    active_jobs=$(jobs -rp | wc -l)
  fi
done

# wait for remaining jobs
wait

# collect open ports from jobs' outputs (jobs printed to stdout)
# Note: We used stdout so open ports were printed live. For a nicer summary:
echo "[*] Scan complete. (Open ports listed above during scan)"

