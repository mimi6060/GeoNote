# GeoNote — Architecture & Features

## Stack
- **Backend**: Go (chi router) + PostgreSQL/PostGIS + Redis + WebSocket
- **Frontend**: Flutter (web + mobile) with flutter_map
- **Infra**: Docker Compose (db, redis, api)

## Project Structure
```
backend/
  cmd/server/main.go          — Entry point, routes, DI
  internal/
    config/                    — Env config loader
    model/                     — Domain models (Message, Interaction, etc.)
    repository/                — DB queries (pgx)
    service/                   — Business logic, caching, gamification
    handler/                   — HTTP handlers (REST API)
    middleware/                — Auth, OptionalAuth, RateLimit, AntiSpam
    cache/                     — Redis cache (grid-based keys)
    ws/                        — WebSocket hub + client
  migrations/                  — SQL migrations (run on DB init)
docker/
  docker-compose.yml           — PostGIS + Redis + API (port 3001)
mobile/
  lib/
    config/                    — API config, theme
    models/                    — Dart models (Message, User)
    providers/                 — State management (ChangeNotifier)
    screens/                   — Map, Feed, Profile, Login
    services/                  — API client, Location, WebSocket
    widgets/                   — CreateSheet, MessagePopup, MessageCard
```

## Database Schema
- **messages**: id, user_id, content, location (geometry Point 4326), visibility, hashtags, message_type, expires_at, mystery_radius, scheduled_at, unlocks_count, likes_count, comments_count
- **interactions**: id, message_id, user_id, type (like/comment), content
- **message_unlocks**: message_id, user_id (mystery unlock tracking)
- **user_streaks**: user_id, current_streak, max_streak, total_posts, total_zones, total_unlocks
- **user_badges**: user_id, badge_type, earned_at

## API Endpoints
### Public
- `GET /api/v1/health`
- `POST /api/v1/auth/register` / `POST /api/v1/auth/login`
- `GET /api/v1/messages/nearby?lat=&lng=&radius=&limit=&sort=&hashtag=` (OptionalAuth)
- `GET /api/v1/heatmap?lat=&lng=&radius=` (OptionalAuth)
- `GET /api/v1/leaderboard?lat=&lng=&radius=` (OptionalAuth)
- `GET /api/v1/events?lat=&lng=&radius=` (OptionalAuth)
- `GET /api/v1/users/{id}/messages`
- `GET /api/v1/users/{id}/profile`
- `GET /api/v1/messages/{id}/comments`

### Authenticated
- `GET /api/v1/auth/me`
- `GET /api/v1/me/profile` — streak + badges
- `POST /api/v1/messages` — create (AntiSpam: 30s cooldown)
- `DELETE /api/v1/messages/{id}`
- `POST /api/v1/messages/{id}/unlock` — mystery unlock (sends lat/lng)
- `POST /api/v1/messages/{id}/like`
- `POST /api/v1/messages/{id}/comments`
- `DELETE /api/v1/comments/{commentId}`

## 5 Viral Features

### 1. Ephemeral Messages (24h)
- Standard messages auto-expire after 24h (`expires_at = NOW() + 24h`)
- SQL function filters: `WHERE expires_at IS NULL OR expires_at > NOW()`
- Creates FOMO — users check daily what's near them

### 2. Mystery Messages (geo-locked)
- `message_type = 'mystery'`, content shows "???" until unlocked
- Must physically go within `mystery_radius` (default 50m) to read
- `POST /messages/{id}/unlock` checks distance via PostGIS
- `message_unlocks` table tracks who unlocked
- Badges: mystery_hunter_5, mystery_hunter_25

### 3. Time Capsules (scheduled reveal)
- `message_type = 'capsule'` with `scheduled_at` timestamp
- Hidden until scheduled time: `WHERE scheduled_at IS NULL OR scheduled_at <= NOW()`
- Expires 24h after reveal
- Flutter UI: date+time picker
- Badge: capsule_creator

### 4. Heatmap (zone activity)
- `GET /heatmap` returns grid-aggregated points (3 decimal precision ~111m)
- SQL function: `get_heatmap(lat, lng, radius)` groups by rounded coords
- Shows where activity is happening in real-time

### 5. Streaks, Badges & Leaderboard
- **Streaks**: consecutive posting days (auto-computed on each post)
- **Badges**: first_post, explorer_5/10/25, streak_3/7/30, mystery_hunter_5/25, capsule_creator
- **Leaderboard**: `GET /leaderboard` — local rankings (30-day window), score = posts*10 + likes*5
- `user_streaks` and `user_badges` tables

### 6. Event Detection (bonus)
- Auto-detects clusters of posts at same location = live event
- SQL function `detect_events(lat, lng, radius)`: groups messages from last 2h by grid cell (~111m)
- Threshold: >= 3 messages from >= 2 distinct users
- Returns: grid coords, message count, user count, top hashtags
- `GET /api/v1/events?lat=&lng=&radius=` (OptionalAuth, radius max 10km)
- Flutter: red fire markers on map, tap for event details popup
- Use cases: concerts, police, sports, protests, accidents

## Performance
- PostGIS `location geometry(Point, 4326)` with GIST index
- Bounding box pre-filter (`ST_MakeEnvelope`) before `ST_DWithin`
- Grid-based Redis cache (`grid:lat3:lng3:radius:uid`)
- Token bucket rate limiter (10 req/s, burst 20)
- Anti-spam: 1 message per 30s per user
- Radius capped at 1000m, limit capped at 50
- Ranked sort: 40% distance + 30% likes(log) + 30% recency(6h half-life)
- Flutter: smart reload (>100m moved AND >5s elapsed)

## Dev Credentials
| Email | Password |
|---|---|
| alice@test.com | password123 |
| bob@test.com | password123 |
| charlie@test.com | password123 |
| diana@test.com | password123 |

## Commands
```bash
# Start backend
cd docker && docker compose up -d --build

# Start frontend
cd mobile && flutter run -d chrome --web-port=8080

# Backend API at http://localhost:3001
# Frontend at http://localhost:8080
```
