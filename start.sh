#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-3000}"

echo "===================================="
echo "  GeoNote MVP - Demarrage Docker"
echo "===================================="
echo ""

# Verifier que Docker est lance
if ! docker info > /dev/null 2>&1; then
  echo "ERREUR: Docker n'est pas lance."
  echo "Demarrez Docker Desktop puis relancez ce script."
  exit 1
fi

cd "$(dirname "$0")"

echo "Port : $PORT"
echo ""

# Arreter les anciens containers si besoin
echo "[1/3] Nettoyage des anciens containers..."
GEONOTE_PORT="$PORT" docker compose down --remove-orphans 2>/dev/null || true

# Rebuild et lancement
echo "[2/3] Build et demarrage des services..."
GEONOTE_PORT="$PORT" docker compose up --build -d

# Attendre que l'app soit prete
echo "[3/3] Attente du demarrage..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:$PORT/api/health" > /dev/null 2>&1; then
    echo ""
    echo "===================================="
    echo "  GeoNote est pret !"
    echo ""
    echo "  http://localhost:$PORT"
    echo "===================================="
    echo ""
    echo "Commandes utiles :"
    echo "  Logs     : docker compose logs -f"
    echo "  Stop     : docker compose down"
    echo "  Restart  : ./start.sh $PORT"
    echo ""
    exit 0
  fi
  sleep 1
done

echo ""
echo "Le demarrage prend plus de temps que prevu."
echo "Verifiez les logs avec : docker compose logs -f"
exit 1
