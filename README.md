# GeoNote

Reseau social geolocalise — laissez des messages partout dans le monde.

## Architecture

| Composant | Technologie |
|-----------|-------------|
| Backend | Go 1.22 (chi, pgx, JWT) |
| Mobile | Flutter 3.19 (iOS + Android) |
| Base de donnees | PostgreSQL 16 + **PostGIS** |
| Cache | **Redis 7** (requetes nearby, TTL 10s) |
| Temps reel | **WebSockets** (gorilla/websocket) |
| Infra | Docker Compose |
| CI/CD | GitHub Actions |

### Points forts pour la scalabilite
- **PostGIS ST_DWithin** + index GIST : recherche spatiale 100x plus rapide que Haversine pur
- **Redis** : cache les requetes nearby pour eviter les hits DB repetitifs
- **WebSockets** : notifications en temps reel (nouveau message, like, commentaire)
- **Marker clustering** cote Flutter pour gerer des milliers de markers

## Structure du projet

```
GeoNote/
├── backend/           # API REST Go
│   ├── cmd/server/    # Point d'entree
│   ├── internal/      # Code metier (handler, service, repository, model, middleware, geo)
│   ├── migrations/    # Scripts SQL
│   └── test/          # Tests d'integration
├── mobile/            # App Flutter
│   ├── lib/           # Code Dart (screens, models, services, providers, widgets)
│   └── test/          # Tests unitaires
├── docker/            # Docker Compose (dev + prod)
├── docs/              # Documentation et specs
└── .github/           # CI/CD + templates issues/PR
```

## Demarrage rapide

### Prerequis

- Docker & Docker Compose
- Go 1.22+ (pour le dev backend local)
- Flutter 3.19+ (pour le dev mobile)

### Tout lancer avec Docker

```bash
make dev          # Lance PostgreSQL + PostGIS + Redis + API Go
make dev-logs     # Voir les logs
make dev-down     # Arreter
make dev-reset    # Reset complet avec donnees fraiches
```

L'API est disponible sur `http://localhost:8080`.
Le WebSocket sur `ws://localhost:8080/ws`.

### Backend seul (dev local)

```bash
cd backend
cp .env.example .env    # Configurer la connexion DB
go run ./cmd/server     # Lancer le serveur
go test ./...           # Lancer les tests
```

### Mobile

```bash
cd mobile
flutter pub get         # Installer les dependances
flutter run             # Lancer l'app
flutter test            # Tests
flutter analyze         # Linter
```

## API Endpoints

| Methode | Route | Auth | Description |
|---------|-------|------|-------------|
| POST | `/api/v1/auth/register` | Non | Inscription |
| POST | `/api/v1/auth/login` | Non | Connexion |
| GET | `/api/v1/auth/me` | Oui | Profil connecte |
| GET | `/api/v1/messages/nearby?lat=&lng=&radius=` | Non | Messages proches |
| POST | `/api/v1/messages` | Oui | Creer un message |
| DELETE | `/api/v1/messages/:id` | Oui | Supprimer (owner) |
| POST | `/api/v1/messages/:id/like` | Oui | Toggle like |
| GET | `/api/v1/messages/:id/comments` | Non | Lire commentaires |
| POST | `/api/v1/messages/:id/comments` | Oui | Ajouter commentaire |
| GET | `/api/v1/users/:id/messages` | Non | Messages d'un user |
| GET | `/api/v1/health` | Non | Health check |
| WS | `/ws` | Non | WebSocket temps reel |

## Utilisateurs de test

| Email | Mot de passe | Username |
|-------|-------------|----------|
| alice@test.com | password123 | alice_explore |
| bob@test.com | password123 | bob_runner |
| charlie@test.com | password123 | charlie_photo |
| diana@test.com | password123 | diana_local |

## Commandes utiles

```bash
make help           # Voir toutes les commandes
make test           # Tests Go
make mobile-test    # Tests Flutter
make lint           # Linter Go
make psql           # Shell PostgreSQL
```

## Contribuer

1. Fork le projet
2. Creer une branche (`git checkout -b feat/ma-feature`)
3. Commit au format [Conventional Commits](https://www.conventionalcommits.org/)
4. Push et ouvrir une Pull Request

## Licence

MIT — voir [LICENSE](LICENSE)
