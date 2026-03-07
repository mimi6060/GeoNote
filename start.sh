#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8080}"

echo "===================================="
echo "  GeoNote - Demarrage Docker"
echo "===================================="
echo ""

# Verifier que Docker est lance
if ! docker info > /dev/null 2>&1; then
  echo "ERREUR: Docker n'est pas lance."
  echo "Demarrez Docker Desktop puis relancez ce script."
  exit 1
fi

cd "$(dirname "$0")"

echo "Port API : $PORT"
echo ""

# Arreter les anciens containers si besoin
echo "[1/3] Nettoyage..."
API_PORT="$PORT" docker compose -f docker/docker-compose.yml down --remove-orphans 2>/dev/null || true

# Build et lancement
echo "[2/3] Build et demarrage (PostGIS + Redis + API Go)..."
API_PORT="$PORT" docker compose -f docker/docker-compose.yml up --build -d

# Attendre que l'API soit prete
echo "[3/3] Attente du demarrage..."
for i in $(seq 1 60); do
  if curl -sf "http://localhost:$PORT/api/v1/health" > /dev/null 2>&1; then
    echo ""
    echo "===================================="
    echo "  GeoNote est pret !"
    echo ""
    echo "  API REST  : http://localhost:$PORT/api/v1"
    echo "  WebSocket : ws://localhost:$PORT/ws"
    echo "  Health    : http://localhost:$PORT/api/v1/health"
    echo "===================================="
    echo ""
    echo "Commandes utiles :"
    echo "  Logs     : docker compose -f docker/docker-compose.yml logs -f api"
    echo "  Stop     : docker compose -f docker/docker-compose.yml down"
    echo "  DB shell : docker compose -f docker/docker-compose.yml exec db psql -U geonote"
    echo "  Restart  : ./start.sh $PORT"
    echo ""
    exit 0
  fi
  printf "."
  sleep 2
done

echo ""
echo "Le demarrage prend plus de temps que prevu."
echo "Verifiez les logs : docker compose -f docker/docker-compose.yml logs -f"
exit 1
