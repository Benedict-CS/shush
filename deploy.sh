#!/usr/bin/env bash
# Sync this repo to a remote server and restart the container.
# Configure SSH host + remote path below or pass via env vars.
#
# Usage:
#   ./deploy.sh                                 # uses env / defaults
#   SHUSH_HOST=user@server SHUSH_PATH=/opt/shush ./deploy.sh
#   ./deploy.sh -h user@server -p /opt/shush

set -e

HOST="${SHUSH_HOST:-}"
REMOTE_PATH="${SHUSH_PATH:-/opt/shush}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--host) HOST="$2"; shift 2 ;;
    -p|--path) REMOTE_PATH="$2"; shift 2 ;;
    --help)
      sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$HOST" ]]; then
  echo "❌ Missing SSH host. Pass -h user@server or set SHUSH_HOST env."
  exit 1
fi

cd "$(dirname "$0")"

echo "🚚 Syncing to ${HOST}:${REMOTE_PATH} ..."
rsync -az --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude '.DS_Store' \
  --exclude '*.log' \
  --exclude 'test-*' \
  ./ "${HOST}:${REMOTE_PATH}/"

echo "🐳 Rebuilding + restarting container on ${HOST} ..."
ssh "${HOST}" "cd '${REMOTE_PATH}' && ./start.sh restart"

echo "✅ Done. Verify on the server:"
echo "   ssh ${HOST} 'curl -I http://localhost:8080/'"
