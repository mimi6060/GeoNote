# Architecture GeoNote

## Vue d'ensemble

```
┌──────────────┐                    ┌──────────────┐
│  App Flutter  │ ◄── HTTP/JSON ──► │  API Go      │
│  (iOS/Android)│                   │  (chi router) │
│               │ ◄── WebSocket ──► │              │
└──────────────┘                    └──────┬───────┘
                                           │
                                    ┌──────┴───────┐
                                    │              │
                              ┌─────▼─────┐  ┌────▼────┐
                              │ PostgreSQL │  │  Redis  │
                              │ + PostGIS  │  │  cache  │
                              └───────────┘  └─────────┘
```

## Backend Go — Architecture en couches

```
cmd/server/main.go           → Point d'entree, injection de dependances
internal/
  config/                    → Chargement variables d'environnement
  model/                     → Structs (User, Message, Interaction, Request, Response)
  repository/                → Acces direct a PostgreSQL (queries SQL + PostGIS)
  service/                   → Logique metier (validation, tri, auth, cache)
  handler/                   → HTTP handlers (parsing request, serialisation response)
  middleware/                → Auth JWT, rate limiting, CORS
  cache/                     → Client Redis (get/set/invalidate)
  ws/                        → Hub WebSocket + client (gorilla/websocket)
  geo/                       → Calculs geographiques (Haversine en Go, PostGIS en SQL)
```

### Flux d'une requete GET /messages/nearby

1. **Middleware** : CORS → RateLimit → Logger
2. **Handler** : parse query params (lat, lng, radius, sort)
3. **Service** : verifie le cache Redis
   - **Cache HIT** → retourne directement les messages serialises
   - **Cache MISS** → appelle le repository
4. **Repository** : execute `get_nearby_messages()` via PostGIS `ST_DWithin`
5. **Service** : stocke le resultat dans Redis (TTL 10s), trie si necessaire
6. **Handler** : serialise la reponse JSON standard

### Flux d'un POST /messages

1. **Middleware** : Auth JWT → verifie le token
2. **Handler** : parse le body, valide (content, lat/lng, visibility)
3. **Service** :
   - Cree le message via le repository
   - **Invalide le cache Redis** (toutes les cles nearby:*)
   - **Broadcast WebSocket** → notifie tous les clients connectes
4. **Handler** : retourne le message cree (201)

## PostGIS — Recherche spatiale

### Pourquoi PostGIS plutot que Haversine pur ?

| Critere | Haversine SQL | PostGIS ST_DWithin |
|---------|---------------|-------------------|
| Index spatial | Non (full scan) | Oui (GIST) |
| Performance 10k messages | ~200ms | ~2ms |
| Performance 1M messages | ~20s | ~5ms |
| Precision | Bonne | Excellente |
| Complexite | Simple | Requiert extension |

### Schema

```sql
-- Colonne geometrie auto-populee via trigger
ALTER TABLE messages ADD COLUMN geom GEOMETRY(Point, 4326);
CREATE INDEX idx_messages_geom ON messages USING GIST(geom);

-- Le trigger auto-peuple geom a partir de lat/lng
CREATE TRIGGER trg_messages_geom
BEFORE INSERT OR UPDATE OF latitude, longitude ON messages
FOR EACH ROW EXECUTE FUNCTION messages_set_geom();
```

### Requete de proximite

```sql
-- ST_DWithin utilise l'index GIST pour un filtrage ultra-rapide
SELECT *, ST_Distance(geom::geography, point::geography) AS distance
FROM messages
WHERE ST_DWithin(geom::geography, point::geography, radius_meters)
ORDER BY distance ASC
LIMIT 50;
```

## Redis — Strategie de cache

- **Cle** : `nearby:{lat:.3f}:{lng:.3f}:{radius}` (arrondi a ~111m)
- **TTL** : 10 secondes (configurable via `CACHE_TTL`)
- **Invalidation** : sur chaque CREATE/DELETE de message, toutes les cles `nearby:*` sont supprimees
- **Fallback** : si Redis est indisponible, le service fonctionne normalement (juste sans cache)

## WebSocket — Temps reel

### Protocole

- Endpoint : `ws://host:port/ws`
- Le serveur envoie des evenements JSON aux clients connectes
- Le client envoie uniquement des pong (heartbeat)

### Format des evenements

```json
{"type": "new_message", "payload": {"id": "...", "content": "...", "latitude": 48.85, ...}}
{"type": "new_like", "payload": {"message_id": "...", "liked": true, "likes_count": 6}}
{"type": "new_comment", "payload": {"message_id": "...", "content": "..."}}
```

### Flutter

- `WsService` singleton gere la connexion avec reconnexion automatique
- `MapScreen` ecoute les evenements et recharge les messages sur `new_message`

## Frontend Flutter — Architecture

```
lib/
  config/          → Configuration API + theme
  models/          → Data classes (User, Message)
  services/        → Communication API (HTTP), WebSocket, Location
  providers/       → State management (ChangeNotifier + Provider)
  screens/         → Pages (Map, Login, Profile, Create)
  widgets/         → Composants reutilisables (MessageCard, MessagePopup)
```

### Marker Clustering

Le package `flutter_map_marker_cluster` regroupe les markers proches en clusters
avec un compteur. Les clusters s'eclatent au zoom pour reveler les markers individuels.

## Securite

- **JWT** pour l'authentification (expiration configurable, HMAC-SHA256)
- **bcrypt** pour le hashage des mots de passe (cost 10)
- **Rate limiting** par IP (100 req/min, in-memory)
- **Validation** des entrees (content 1-500, coordonnees, visibility enum)
- **Requetes parametrees** (pas d'injection SQL)
- **CORS** configurable
- **WebSocket origin check** desactive en dev, a configurer en production
