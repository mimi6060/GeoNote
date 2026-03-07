-- Donnees de test pour le developpement
-- Mot de passe pour tous les users: "password123" (bcrypt hash)

INSERT INTO users (id, username, email, password_hash, is_anonymous, created_at) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'alice_explore', 'alice@test.com',
   '$2a$10$Yu6IB6EWncoERbvtL3z51eenK6Fq06zWFBO6r8Yb9NzIRweMRZKXu', false, '2026-03-01 10:00:00+00'),
  ('b2222222-2222-2222-2222-222222222222', 'bob_runner', 'bob@test.com',
   '$2a$10$Yu6IB6EWncoERbvtL3z51eenK6Fq06zWFBO6r8Yb9NzIRweMRZKXu', false, '2026-03-01 11:00:00+00'),
  ('c3333333-3333-3333-3333-333333333333', 'charlie_photo', 'charlie@test.com',
   '$2a$10$Yu6IB6EWncoERbvtL3z51eenK6Fq06zWFBO6r8Yb9NzIRweMRZKXu', false, '2026-03-02 09:00:00+00'),
  ('d4444444-4444-4444-4444-444444444444', 'diana_local', 'diana@test.com',
   '$2a$10$Yu6IB6EWncoERbvtL3z51eenK6Fq06zWFBO6r8Yb9NzIRweMRZKXu', false, '2026-03-02 14:00:00+00'),
  ('e5555555-5555-5555-5555-555555555555', 'anon_user', 'anon@test.com',
   '$2a$10$Yu6IB6EWncoERbvtL3z51eenK6Fq06zWFBO6r8Yb9NzIRweMRZKXu', true, '2026-03-03 08:00:00+00');

INSERT INTO messages (id, user_id, content, latitude, longitude, visibility, hashtags, likes_count, comments_count, created_at) VALUES
  ('a0000001-0000-0000-0000-000000000001', 'a1111111-1111-1111-1111-111111111111',
   'Superbe vue depuis la Tour Eiffel ce matin !', 48.8584, 2.2945,
   'public', ARRAY['paris', 'tourisme'], 12, 3, '2026-03-04 08:30:00+00'),
  ('a0000002-0000-0000-0000-000000000002', 'b2222222-2222-2222-2222-222222222222',
   'Meilleur cafe du quartier, je recommande !', 48.8566, 2.3522,
   'public', ARRAY['cafe', 'bonplan'], 8, 1, '2026-03-04 09:15:00+00'),
  ('a0000003-0000-0000-0000-000000000003', 'c3333333-3333-3333-3333-333333333333',
   'Street art incroyable dans cette ruelle', 48.8650, 2.3800,
   'public', ARRAY['art', 'streetart'], 25, 5, '2026-03-04 10:00:00+00'),
  ('a0000004-0000-0000-0000-000000000004', 'a1111111-1111-1111-1111-111111111111',
   'Petit parc cache, parfait pour lire', 48.8462, 2.3371,
   'public', ARRAY['calme', 'nature'], 6, 0, '2026-03-04 11:00:00+00'),
  ('a0000005-0000-0000-0000-000000000005', 'd4444444-4444-4444-4444-444444444444',
   'Attention travaux rue de Rivoli, passage difficile', 48.8606, 2.3376,
   'public', ARRAY['info', 'travaux'], 3, 2, '2026-03-04 12:00:00+00'),
  ('a0000006-0000-0000-0000-000000000006', 'e5555555-5555-5555-5555-555555555555',
   'Quelqu''un a perdu des cles pres du metro Chatelet', 48.8584, 2.3474,
   'public', ARRAY['perdu'], 1, 4, '2026-03-04 13:30:00+00'),
  ('a0000007-0000-0000-0000-000000000007', 'b2222222-2222-2222-2222-222222222222',
   'Concert gratuit ce soir au Sacre-Coeur !', 48.8867, 2.3431,
   'public', ARRAY['musique', 'gratuit'], 45, 8, '2026-03-04 14:00:00+00'),
  ('a0000008-0000-0000-0000-000000000008', 'c3333333-3333-3333-3333-333333333333',
   'Le marche bio du dimanche est top', 48.8530, 2.3499,
   'public', ARRAY['bio', 'marche'], 15, 2, '2026-03-05 07:00:00+00'),
  ('a0000009-0000-0000-0000-000000000009', 'd4444444-4444-4444-4444-444444444444',
   'Spot secret pour voir le coucher de soleil', 48.8420, 2.2880,
   'friends', ARRAY['sunset', 'secret'], 20, 6, '2026-03-05 18:00:00+00'),
  ('a0000010-0000-0000-0000-000000000010', 'a1111111-1111-1111-1111-111111111111',
   'Nouveau restaurant japonais, excellent ramen !', 48.8690, 2.3320,
   'public', ARRAY['food', 'japon'], 18, 3, '2026-03-05 19:30:00+00');

INSERT INTO interactions (id, message_id, user_id, type, content, created_at) VALUES
  ('b0000001-0000-0000-0000-000000000001',
   'a0000001-0000-0000-0000-000000000001', 'b2222222-2222-2222-2222-222222222222',
   'like', NULL, '2026-03-04 09:00:00+00'),
  ('b0000002-0000-0000-0000-000000000002',
   'a0000001-0000-0000-0000-000000000001', 'c3333333-3333-3333-3333-333333333333',
   'comment', 'Trop beau ! J''y etais hier aussi', '2026-03-04 09:30:00+00'),
  ('b0000003-0000-0000-0000-000000000003',
   'a0000007-0000-0000-0000-000000000007', 'a1111111-1111-1111-1111-111111111111',
   'like', NULL, '2026-03-04 14:30:00+00'),
  ('b0000004-0000-0000-0000-000000000004',
   'a0000007-0000-0000-0000-000000000007', 'd4444444-4444-4444-4444-444444444444',
   'comment', 'C''est a quelle heure exactement ?', '2026-03-04 15:00:00+00'),
  ('b0000005-0000-0000-0000-000000000005',
   'a0000003-0000-0000-0000-000000000003', 'e5555555-5555-5555-5555-555555555555',
   'comment', 'Tu peux donner l''adresse exacte ?', '2026-03-04 10:30:00+00');

INSERT INTO beta_signups (email) VALUES
  ('testeur1@example.com'),
  ('testeur2@example.com'),
  ('testeur3@example.com');
