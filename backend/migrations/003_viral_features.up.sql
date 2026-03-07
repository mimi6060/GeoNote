-- =============================================================
-- Migration 003: Viral Features
-- 1. Ephemeral messages (24h auto-expiry)
-- 2. Mystery messages (geo-locked, must be nearby to read)
-- 3. Time capsules (scheduled future reveal)
-- 4. Heatmap (zone activity aggregation)
-- 5. Streaks, badges & leaderboard
-- =============================================================

-- ---- 1. Message types & expiry ----
ALTER TABLE messages ADD COLUMN message_type VARCHAR(10) NOT NULL DEFAULT 'standard';
ALTER TABLE messages ADD COLUMN expires_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN mystery_radius INTEGER DEFAULT 50;
ALTER TABLE messages ADD COLUMN scheduled_at TIMESTAMPTZ;
ALTER TABLE messages ADD COLUMN unlocks_count INTEGER DEFAULT 0;

ALTER TABLE messages ADD CONSTRAINT valid_message_type
    CHECK (message_type IN ('standard', 'mystery', 'capsule'));

-- Default: standard messages expire in 24h
-- Mystery messages never auto-expire
-- Capsules expire 24h after their scheduled reveal

CREATE INDEX idx_messages_expires_at ON messages(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_messages_scheduled_at ON messages(scheduled_at) WHERE scheduled_at IS NOT NULL;
CREATE INDEX idx_messages_type ON messages(message_type);

-- ---- 2. Mystery message unlocks ----
CREATE TABLE message_unlocks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

CREATE INDEX idx_unlocks_message ON message_unlocks(message_id);
CREATE INDEX idx_unlocks_user ON message_unlocks(user_id);

-- Trigger: increment unlocks_count on unlock
CREATE OR REPLACE FUNCTION update_unlock_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE messages SET unlocks_count = unlocks_count + 1 WHERE id = NEW.message_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_unlock_count
AFTER INSERT ON message_unlocks
FOR EACH ROW EXECUTE FUNCTION update_unlock_count();

-- ---- 3. User streaks & stats ----
CREATE TABLE user_streaks (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0,
    max_streak INTEGER DEFAULT 0,
    last_post_date DATE,
    total_posts INTEGER DEFAULT 0,
    total_zones INTEGER DEFAULT 0,
    total_unlocks INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---- 4. Badges ----
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_type VARCHAR(30) NOT NULL,
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, badge_type)
);

CREATE INDEX idx_badges_user ON user_badges(user_id);

-- Valid badge types:
-- first_post, explorer_5, explorer_10, explorer_25
-- streak_3, streak_7, streak_30
-- mystery_hunter_5, mystery_hunter_25
-- local_legend (top 1 in zone)
-- capsule_creator

-- ---- 5. Update get_nearby_messages to filter expired & scheduled ----
DROP FUNCTION IF EXISTS get_nearby_messages(DOUBLE PRECISION, DOUBLE PRECISION, INTEGER, INTEGER, UUID);
CREATE OR REPLACE FUNCTION get_nearby_messages(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 500,
    msg_limit INTEGER DEFAULT 50,
    current_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID, user_id UUID, username VARCHAR, content TEXT,
    latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
    visibility VARCHAR, hashtags TEXT[],
    likes_count INTEGER, comments_count INTEGER,
    created_at TIMESTAMPTZ, distance_meters DOUBLE PRECISION,
    message_type VARCHAR, expires_at TIMESTAMPTZ,
    mystery_radius INTEGER, scheduled_at TIMESTAMPTZ,
    unlocks_count INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    delta_lat DOUBLE PRECISION := (radius_meters::DOUBLE PRECISION / 111000.0) * 1.2;
    delta_lng DOUBLE PRECISION := (radius_meters::DOUBLE PRECISION / (111000.0 * COS(RADIANS(user_lat)))) * 1.2;
    user_point GEOMETRY := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326);
BEGIN
    RETURN QUERY
    SELECT
        m.id, m.user_id, u.username, m.content,
        ST_Y(m.location) AS latitude, ST_X(m.location) AS longitude,
        m.visibility, m.hashtags,
        m.likes_count, m.comments_count, m.created_at,
        ST_Distance(m.location::geography, user_point::geography) AS distance_meters,
        m.message_type, m.expires_at, m.mystery_radius, m.scheduled_at, m.unlocks_count
    FROM messages m
    JOIN users u ON m.user_id = u.id
    WHERE
        -- Bounding box pre-filter
        m.location && ST_MakeEnvelope(
            user_lng - delta_lng, user_lat - delta_lat,
            user_lng + delta_lng, user_lat + delta_lat, 4326
        )
        AND ST_DWithin(m.location::geography, user_point::geography, radius_meters)
        -- Visibility
        AND (m.visibility = 'public' OR (current_user_id IS NOT NULL AND m.user_id = current_user_id))
        -- Not expired
        AND (m.expires_at IS NULL OR m.expires_at > NOW())
        -- Capsules: only show if scheduled time has passed
        AND (m.scheduled_at IS NULL OR m.scheduled_at <= NOW())
    ORDER BY distance_meters ASC
    LIMIT msg_limit;
END;
$$;

-- ---- 6. Heatmap aggregation function ----
CREATE OR REPLACE FUNCTION get_heatmap(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 1000
)
RETURNS TABLE (
    grid_lat DOUBLE PRECISION,
    grid_lng DOUBLE PRECISION,
    intensity INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    user_point GEOMETRY := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326);
BEGIN
    RETURN QUERY
    SELECT
        ROUND(ST_Y(m.location)::NUMERIC, 3)::DOUBLE PRECISION AS grid_lat,
        ROUND(ST_X(m.location)::NUMERIC, 3)::DOUBLE PRECISION AS grid_lng,
        COUNT(*)::INTEGER AS intensity
    FROM messages m
    WHERE
        ST_DWithin(m.location::geography, user_point::geography, radius_meters)
        AND (m.expires_at IS NULL OR m.expires_at > NOW())
        AND (m.scheduled_at IS NULL OR m.scheduled_at <= NOW())
        AND m.visibility = 'public'
    GROUP BY grid_lat, grid_lng
    ORDER BY intensity DESC;
END;
$$;

-- ---- 7. Leaderboard function ----
CREATE OR REPLACE FUNCTION get_leaderboard(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 5000,
    lim INTEGER DEFAULT 20
)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    total_posts BIGINT,
    total_likes BIGINT,
    score BIGINT
) LANGUAGE plpgsql AS $$
DECLARE
    user_point GEOMETRY := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326);
BEGIN
    RETURN QUERY
    SELECT
        m.user_id,
        u.username,
        COUNT(*)::BIGINT AS total_posts,
        COALESCE(SUM(m.likes_count), 0)::BIGINT AS total_likes,
        (COUNT(*) * 10 + COALESCE(SUM(m.likes_count), 0) * 5)::BIGINT AS score
    FROM messages m
    JOIN users u ON m.user_id = u.id
    WHERE
        ST_DWithin(m.location::geography, user_point::geography, radius_meters)
        AND m.created_at > NOW() - INTERVAL '30 days'
    GROUP BY m.user_id, u.username
    ORDER BY score DESC
    LIMIT lim;
END;
$$;

-- Initialize streaks for existing users
INSERT INTO user_streaks (user_id, total_posts)
SELECT u.id, COALESCE(mc.cnt, 0)
FROM users u
LEFT JOIN (SELECT user_id, COUNT(*) as cnt FROM messages GROUP BY user_id) mc ON mc.user_id = u.id
ON CONFLICT DO NOTHING;
