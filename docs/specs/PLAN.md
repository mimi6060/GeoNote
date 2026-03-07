# GeoNote MVP - Plan BMAD Complet

## Vue d'ensemble

GeoNote est un reseau social geolocalise permettant de laisser des messages attaches a une position GPS et de decouvrir les messages autour de soi sur une carte interactive.

---

## Structure du projet

```
bmad/
├── PLAN.md                          # Ce fichier
├── database/
│   ├── schema.json                  # Schema BMAD complet (tables, champs, relations)
│   ├── migrations.sql               # SQL pour creer les tables + fonctions
│   ├── seed.sql                     # Donnees de test (5 users, 15 messages, 5 interactions)
│   └── test-data.json               # Donnees de test au format JSON
├── pages/
│   ├── 01-landing.json              # Landing page / collecte beta
│   ├── 02-map.json                  # Carte principale interactive
│   ├── 03-create-message.json       # Modal creation de message
│   └── 04-profile.json              # Profil utilisateur
├── workflows/
│   ├── 01-create-message.json       # Workflow: publier un message
│   ├── 02-get-nearby-messages.json  # Workflow: charger messages proches
│   ├── 03-interactions.json         # Workflows: like, comment, get_comments
│   └── 04-user-actions.json         # Workflows: beta signup, profil, suppression
└── components/
    ├── index.html                   # Page HTML complete de la carte
    ├── map.js                       # Logique JS Leaflet + interactions
    └── styles.css                   # Styles CSS complets
```

---

## 1. Base de donnees

### Tables

| Table          | Description                        | Champs cles                                    |
|----------------|------------------------------------|-------------------------------------------------|
| users          | Utilisateurs                       | id, username, email, is_anonymous, created_at   |
| messages       | Messages geolocalises              | id, user_id, content, lat, lng, visibility, hashtags |
| interactions   | Likes et commentaires              | id, message_id, user_id, type, content          |
| beta_signups   | Emails beta testeurs               | id, email, created_at                           |

### Relations
- `messages.user_id` → `users.id` (many-to-one)
- `interactions.message_id` → `messages.id` (many-to-one)
- `interactions.user_id` → `users.id` (many-to-one)

### Fonction SQL cle
- `get_nearby_messages(lat, lng, radius, limit)` — Recherche par proximite avec calcul Haversine

### Trigger automatique
- `trg_interaction_counts` — Met a jour `likes_count` et `comments_count` sur insert/delete d'interactions

---

## 2. Pages

| Page             | Route      | Auth | Description                              |
|------------------|------------|------|------------------------------------------|
| Landing Beta     | /          | Non  | Presentation + collecte emails           |
| Carte principale | /map       | Non  | Carte Leaflet + markers + popups         |
| Creation message | /map modal | Oui  | Formulaire dans un modal sur la carte    |
| Profil           | /profile   | Oui  | Liste des messages + stats + suppression |

---

## 3. Workflows

| Workflow              | Trigger              | Description                              |
|-----------------------|----------------------|------------------------------------------|
| create_message        | form_submit          | Valide, extrait hashtags, insere en DB   |
| get_nearby_messages   | page_load / map_move | Requete proximite + filtres + tri        |
| toggle_like           | button_click         | Ajoute ou retire un like (toggle)        |
| add_comment           | form_submit          | Valide et insere un commentaire          |
| get_comments          | button_click         | Charge les commentaires d'un message     |
| beta_signup           | form_submit          | Valide email, verifie doublon, insere    |
| get_user_messages     | page_load            | Charge messages + stats du profil        |
| delete_message        | button_click         | Verifie ownership puis supprime          |
| center_on_user        | button_click         | Geolocalise et recentre la carte         |
| filter_by_hashtag     | input_change         | Filtre les markers par hashtag           |

---

## 4. Validations

| Champ              | Regles                                          |
|--------------------|--------------------------------------------------|
| username           | 3-30 chars, alphanumerique + underscore          |
| email              | Format email valide, unique                      |
| message content    | 1-500 chars, non vide, sanitize HTML             |
| latitude           | -90 a 90                                         |
| longitude          | -180 a 180                                       |
| visibility         | enum: public, friends, private                   |
| comment content    | 1-300 chars, requis si type=comment              |
| interaction type   | enum: like, comment                              |

---

## 5. Donnees de test

- **5 utilisateurs** : alice_explore, bob_runner, charlie_photo, diana_local, anon_user
- **15 messages** : repartis dans Paris (Tour Eiffel, Chatelet, Sacre-Coeur, Canal Saint-Martin...)
- **5 interactions** : 2 likes + 3 commentaires
- **3 inscriptions beta**

Toutes les coordonnees sont dans Paris pour faciliter les tests.

---

## 6. Stack technique recommandee

| Couche    | Technologie                       |
|-----------|-----------------------------------|
| Frontend  | HTML/CSS/JS + Leaflet 1.9         |
| Backend   | BMAD workflows / Supabase         |
| DB        | PostgreSQL (Supabase)             |
| Carte     | Leaflet + OpenStreetMap (gratuit) |
| Hosting   | Vercel / Netlify (frontend)       |
| Auth      | Supabase Auth (optionnel MVP)     |

---

## 7. Mise en route rapide

1. Creer un projet Supabase
2. Executer `database/migrations.sql` dans l'editeur SQL
3. Executer `database/seed.sql` pour les donnees de test
4. Configurer les workflows BMAD avec les fichiers `workflows/*.json`
5. Deployer `components/index.html` + `map.js` + `styles.css`
6. Adapter `GEONOTE_CONFIG.api.baseUrl` dans `map.js` vers votre API Supabase
7. Tester la carte, la creation de messages et les interactions

Le MVP est fonctionnel sans code supplementaire a ecrire.
