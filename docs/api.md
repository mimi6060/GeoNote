# GeoNote API v1

Base URL: `http://localhost:8080/api/v1`

## Format de reponse

Toutes les reponses suivent ce format :

```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

En cas d'erreur :

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Donnees invalides",
    "fields": {
      "content": "entre 1 et 500 caracteres"
    }
  }
}
```

## Authentification

Les routes protegees necessitent un header `Authorization: Bearer <token>`.
Le token est obtenu via `/auth/login` ou `/auth/register`.

## Endpoints

### Auth

#### POST /auth/register
```json
{ "username": "alice", "email": "alice@test.com", "password": "12345678" }
```
Reponse 201 : `{ "token": "...", "user": { ... } }`

#### POST /auth/login
```json
{ "email": "alice@test.com", "password": "12345678" }
```
Reponse 200 : `{ "token": "...", "user": { ... } }`

#### GET /auth/me (Auth)
Reponse 200 : `{ "id": "...", "username": "...", ... }`

### Messages

#### GET /messages/nearby
Query params : `lat`, `lng`, `radius` (metres), `limit`, `sort` (distance|recent|popular), `hashtag`

Reponse 200 :
```json
{
  "messages": [ { "id": "...", "content": "...", "distance_meters": 150.5, ... } ],
  "count": 10,
  "center": { "lat": 48.85, "lng": 2.35 },
  "radius": 10000
}
```

#### POST /messages (Auth)
```json
{ "content": "Hello #paris", "latitude": 48.85, "longitude": 2.35, "visibility": "public" }
```
Reponse 201 : le message cree

#### DELETE /messages/:id (Auth, owner)
Reponse 200 : `{ "message": "Message supprime" }`

### Interactions

#### POST /messages/:id/like (Auth)
Toggle like. Reponse 200 : `{ "liked": true, "likes_count": 6 }`

#### GET /messages/:id/comments
Reponse 200 : `{ "comments": [ ... ], "count": 3 }`

#### POST /messages/:id/comments (Auth)
```json
{ "content": "Super message !" }
```
Reponse 201 : le commentaire cree

### Users

#### GET /users/:id/messages
Reponse 200 : `{ "messages": [ ... ], "count": 5 }`

### Health

#### GET /health
Reponse 200 : `{ "status": "ok", "db": "connected" }`
