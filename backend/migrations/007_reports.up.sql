-- =============================================================
-- Migration 007: Enhanced Reports / Moderation
-- - Add description column to content_reports
-- - Constrain reason to specific values
-- - Add resolved_at timestamp
-- - Add is_hidden to messages for auto-moderation
-- - Update get_nearby_messages to filter hidden messages
-- =============================================================

-- ---- 1. Enhance content_reports table ----
ALTER TABLE content_reports ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '';
ALTER TABLE content_reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

-- Drop the old open-ended check on reason, replace with enum-like constraint
ALTER TABLE content_reports DROP CONSTRAINT IF EXISTS content_reports_reason_check;
ALTER TABLE content_reports ADD CONSTRAINT valid_report_reason
    CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'misinformation', 'other'));

-- ---- 2. Add is_hidden to messages for auto-moderation ----
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_messages_is_hidden ON messages(is_hidden) WHERE is_hidden = true;

-- ---- 3. Update get_nearby_messages to filter hidden messages ----
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
        -- Not hidden by moderation
        AND m.is_hidden = false
    ORDER BY distance_meters ASC
    LIMIT msg_limit;
END;
$$;
