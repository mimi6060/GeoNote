-- GeoNote MVP - Donnees de test
-- Executez apres migrations.sql

-- ============================================
-- UTILISATEURS TEST
-- ============================================
INSERT INTO users (id, username, email, is_anonymous, created_at) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'alice_explore', 'alice@test.com', false, '2026-03-01 10:00:00+00'),
  ('b2222222-2222-2222-2222-222222222222', 'bob_runner', 'bob@test.com', false, '2026-03-01 11:00:00+00'),
  ('c3333333-3333-3333-3333-333333333333', 'charlie_photo', 'charlie@test.com', false, '2026-03-02 09:00:00+00'),
  ('d4444444-4444-4444-4444-444444444444', 'diana_local', 'diana@test.com', false, '2026-03-02 14:00:00+00'),
  ('e5555555-5555-5555-5555-555555555555', 'anon_user', 'anon@test.com', true, '2026-03-03 08:00:00+00');

-- ============================================
-- MESSAGES TEST (15 messages, coordonnees Paris)
-- ============================================
INSERT INTO messages (id, user_id, content, latitude, longitude, visibility, hashtags, likes_count, comments_count, created_at) VALUES
  ('m0000001-0000-0000-0000-000000000001', 'a1111111-1111-1111-1111-111111111111',
   'Superbe vue depuis la Tour Eiffel ce matin !', 48.8584, 2.2945,
   'public', ARRAY['paris', 'tourisme'], 12, 3, '2026-03-04 08:30:00+00'),

  ('m0000002-0000-0000-0000-000000000002', 'b2222222-2222-2222-2222-222222222222',
   'Meilleur cafe du quartier, je recommande !', 48.8566, 2.3522,
   'public', ARRAY['cafe', 'bonplan'], 8, 1, '2026-03-04 09:15:00+00'),

  ('m0000003-0000-0000-0000-000000000003', 'c3333333-3333-3333-3333-333333333333',
   'Street art incroyable dans cette ruelle', 48.8650, 2.3800,
   'public', ARRAY['art', 'streetart'], 25, 5, '2026-03-04 10:00:00+00'),

  ('m0000004-0000-0000-0000-000000000004', 'a1111111-1111-1111-1111-111111111111',
   'Petit parc cache, parfait pour lire', 48.8462, 2.3371,
   'public', ARRAY['calme', 'nature'], 6, 0, '2026-03-04 11:00:00+00'),

  ('m0000005-0000-0000-0000-000000000005', 'd4444444-4444-4444-4444-444444444444',
   'Attention travaux rue de Rivoli, passage difficile', 48.8606, 2.3376,
   'public', ARRAY['info', 'travaux'], 3, 2, '2026-03-04 12:00:00+00'),

  ('m0000006-0000-0000-0000-000000000006', 'e5555555-5555-5555-5555-555555555555',
   'Quelqu''un a perdu des cles pres du metro Chatelet', 48.8584, 2.3474,
   'public', ARRAY['perdu'], 1, 4, '2026-03-04 13:30:00+00'),

  ('m0000007-0000-0000-0000-000000000007', 'b2222222-2222-2222-2222-222222222222',
   'Concert gratuit ce soir au Sacre-Coeur !', 48.8867, 2.3431,
   'public', ARRAY['musique', 'gratuit'], 45, 8, '2026-03-04 14:00:00+00'),

  ('m0000008-0000-0000-0000-000000000008', 'c3333333-3333-3333-3333-333333333333',
   'Le marche bio du dimanche est top', 48.8530, 2.3499,
   'public', ARRAY['bio', 'marche'], 15, 2, '2026-03-05 07:00:00+00'),

  ('m0000009-0000-0000-0000-000000000009', 'd4444444-4444-4444-4444-444444444444',
   'Spot secret pour voir le coucher de soleil', 48.8420, 2.2880,
   'friends', ARRAY['sunset', 'secret'], 20, 6, '2026-03-05 18:00:00+00'),

  ('m0000010-0000-0000-0000-000000000010', 'a1111111-1111-1111-1111-111111111111',
   'Nouveau restaurant japonais, excellent ramen !', 48.8690, 2.3320,
   'public', ARRAY['food', 'japon'], 18, 3, '2026-03-05 19:30:00+00'),

  ('m0000011-0000-0000-0000-000000000011', 'e5555555-5555-5555-5555-555555555555',
   'Wifi gratuit dans ce parc, pratique pour bosser', 48.8651, 2.3212,
   'public', ARRAY['wifi', 'remote'], 30, 4, '2026-03-06 10:00:00+00'),

  ('m0000012-0000-0000-0000-000000000012', 'b2222222-2222-2222-2222-222222222222',
   'Balade le long du canal Saint-Martin', 48.8710, 2.3650,
   'public', ARRAY['balade', 'canal'], 22, 1, '2026-03-06 11:00:00+00'),

  ('m0000013-0000-0000-0000-000000000013', 'c3333333-3333-3333-3333-333333333333',
   'Note perso : revenir ici pour photographier la nuit', 48.8530, 2.3690,
   'private', ARRAY[]::TEXT[], 0, 0, '2026-03-06 15:00:00+00'),

  ('m0000014-0000-0000-0000-000000000014', 'd4444444-4444-4444-4444-444444444444',
   'Place parfaite pour un pique-nique', 48.8556, 2.3130,
   'public', ARRAY['picnic', 'ete'], 9, 2, '2026-03-06 16:00:00+00'),

  ('m0000015-0000-0000-0000-000000000015', 'a1111111-1111-1111-1111-111111111111',
   'Librairie independante avec une super selection', 48.8490, 2.3560,
   'public', ARRAY['livres', 'culture'], 14, 3, '2026-03-07 09:00:00+00');

-- ============================================
-- INTERACTIONS TEST (5 interactions)
-- ============================================
INSERT INTO interactions (id, message_id, user_id, type, content, created_at) VALUES
  ('i0000001-0000-0000-0000-000000000001',
   'm0000001-0000-0000-0000-000000000001', 'b2222222-2222-2222-2222-222222222222',
   'like', NULL, '2026-03-04 09:00:00+00'),

  ('i0000002-0000-0000-0000-000000000002',
   'm0000001-0000-0000-0000-000000000001', 'c3333333-3333-3333-3333-333333333333',
   'comment', 'Trop beau ! J''y etais hier aussi', '2026-03-04 09:30:00+00'),

  ('i0000003-0000-0000-0000-000000000003',
   'm0000007-0000-0000-0000-000000000007', 'a1111111-1111-1111-1111-111111111111',
   'like', NULL, '2026-03-04 14:30:00+00'),

  ('i0000004-0000-0000-0000-000000000004',
   'm0000007-0000-0000-0000-000000000007', 'd4444444-4444-4444-4444-444444444444',
   'comment', 'C''est a quelle heure exactement ?', '2026-03-04 15:00:00+00'),

  ('i0000005-0000-0000-0000-000000000005',
   'm0000003-0000-0000-0000-000000000003', 'e5555555-5555-5555-5555-555555555555',
   'comment', 'Tu peux donner l''adresse exacte ?', '2026-03-04 10:30:00+00');

-- ============================================
-- BETA SIGNUPS TEST
-- ============================================
INSERT INTO beta_signups (email) VALUES
  ('testeur1@example.com'),
  ('testeur2@example.com'),
  ('testeur3@example.com');
