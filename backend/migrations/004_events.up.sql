-- =============================================================
-- Migration 004: Event Detection
-- Auto-detect clusters of posts at same location = "event"
-- Examples: Concert, Police, Match, Manifestation
-- =============================================================

-- ---- 1. Events table (detected events cache) ----
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grid_lat DOUBLE PRECISION NOT NULL,
    grid_lng DOUBLE PRECISION NOT NULL,
    label VARCHAR(50) DEFAULT 'event',
    message_count INTEGER NOT NULL DEFAULT 0,
    user_count INTEGER NOT NULL DEFAULT 0,
    first_message_at TIMESTAMPTZ NOT NULL,
    last_message_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_location ON events(grid_lat, grid_lng);
CREATE INDEX IF NOT EXISTS idx_events_expires ON events(expires_at);

-- ---- 2. Detect events function ----
-- Finds clusters of recent messages (last 2h) at same grid cell (~111m)
-- Minimum: 3 messages from 2+ distinct users
CREATE OR REPLACE FUNCTION detect_events(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 5000
)
RETURNS TABLE (
    grid_lat DOUBLE PRECISION,
    grid_lng DOUBLE PRECISION,
    message_count BIGINT,
    user_count BIGINT,
    first_message_at TIMESTAMPTZ,
    last_message_at TIMESTAMPTZ,
    top_hashtags TEXT[]
) LANGUAGE plpgsql AS $$
DECLARE
    user_point GEOMETRY := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326);
BEGIN
    RETURN QUERY
    SELECT
        ROUND(ST_Y(m.location)::NUMERIC, 3)::DOUBLE PRECISION AS g_lat,
        ROUND(ST_X(m.location)::NUMERIC, 3)::DOUBLE PRECISION AS g_lng,
        COUNT(*)::BIGINT AS msg_count,
        COUNT(DISTINCT m.user_id)::BIGINT AS usr_count,
        MIN(m.created_at) AS first_msg,
        MAX(m.created_at) AS last_msg,
        -- Collect up to 5 distinct hashtags from the cluster
        (ARRAY_AGG(DISTINCT tag_val) FILTER (WHERE tag_val IS NOT NULL))[1:5] AS top_tags
    FROM messages m
    LEFT JOIN LATERAL UNNEST(m.hashtags) AS tag_val ON true
    WHERE
        ST_DWithin(m.location::geography, user_point::geography, radius_meters)
        AND m.created_at > NOW() - INTERVAL '2 hours'
        AND m.visibility = 'public'
        AND (m.expires_at IS NULL OR m.expires_at > NOW())
    GROUP BY g_lat, g_lng
    HAVING COUNT(DISTINCT m.id) >= 3 AND COUNT(DISTINCT m.user_id) >= 2
    ORDER BY msg_count DESC;
END;
$$;
