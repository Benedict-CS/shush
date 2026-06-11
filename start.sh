#!/usr/bin/env bash
# Shush - Docker startup script
# Usage:
#   ./start.sh              # build + run in background on port 8080
#   ./start.sh -p 9000      # use a different host port
#   ./start.sh --logs       # tail logs after starting
#   ./start.sh stop         # stop and remove the container
#   ./start.sh restart      # rebuild + restart
set -e

PORT=8080
FOLLOW_LOGS=0
ACTION="up"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--port)  PORT="$2"; shift 2 ;;
    --logs)     FOLLOW_LOGS=1; shift ;;
    stop)       ACTION="stop"; shift ;;
    restart)    ACTION="restart"; shift ;;
    -h|--help)
      sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker not found. Install Docker first."; exit 1
fi

COMPOSE="docker compose"
if ! docker compose version >/dev/null 2>&1; then
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
  else
    echo "❌ docker compose not found."; exit 1
  fi
fi

export SHUSH_PORT="$PORT"

case "$ACTION" in
  stop)
    echo "⏹  Stopping shush..."
    $COMPOSE down
    ;;
  restart)
    echo "🔄 Rebuilding + restarting on port $PORT..."
    $COMPOSE down
    $COMPOSE up -d --build
    ;;
  up)
    echo "🐳 Building + starting shush on host port $PORT..."
    $COMPOSE up -d --build
    echo ""
    echo "✅ Running at: http://localhost:$PORT/"
    echo "   Container: $($COMPOSE ps --format '{{.Name}}' 2>/dev/null | head -1)"
    echo ""
    echo "Useful:"
    echo "  ./start.sh --logs    # tail logs"
    echo "  ./start.sh stop      # stop"
    echo "  ./start.sh restart   # rebuild"
    ;;
esac

if [[ "$FOLLOW_LOGS" == "1" ]]; then
  echo ""; echo "📜 Tailing logs (Ctrl+C to detach)..."
  $COMPOSE logs -f
fi
