-- GeoNote MVP - Schema SQL

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    avatar_url TEXT,
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_]{3,30}$')
);

-- messages
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    visibility VARCHAR(10) NOT NULL DEFAULT 'public',
    hashtags TEXT[] DEFAULT '{}',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT content_not_empty CHECK (char_length(content) > 0),
    CONSTRAINT content_max_length CHECK (char_length(content) <= 500),
    CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180),
    CONSTRAINT valid_visibility CHECK (visibility IN ('public', 'friends', 'private'))
);

CREATE INDEX idx_messages_user_id ON messages(user_id);
CREATE INDEX idx_messages_location ON messages(latitude, longitude);
CREATE INDEX idx_messages_visibility ON messages(visibility);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);

-- interactions
CREATE TABLE interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(10) NOT NULL,
    content TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT valid_type CHECK (type IN ('like', 'comment')),
    CONSTRAINT comment_has_content CHECK (
        (type = 'comment' AND content IS NOT NULL AND char_length(content) > 0)
        OR type = 'like'
    ),
    CONSTRAINT one_like_per_user_per_message UNIQUE (message_id, user_id, type)
);

CREATE INDEX idx_interactions_message_id ON interactions(message_id);
CREATE INDEX idx_interactions_user_id ON interactions(user_id);

-- beta signups
CREATE TABLE beta_signups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Nearby messages function (Haversine)
CREATE OR REPLACE FUNCTION get_nearby_messages(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 500,
    msg_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    username VARCHAR,
    content TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    visibility VARCHAR,
    hashtags TEXT[],
    likes_count INTEGER,
    comments_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id, m.user_id, u.username, m.content,
        m.latitude, m.longitude, m.visibility, m.hashtags,
        m.likes_count, m.comments_count, m.created_at,
        (6371000 * acos(
            cos(radians(user_lat)) * cos(radians(m.latitude)) *
            cos(radians(m.longitude) - radians(user_lng)) +
            sin(radians(user_lat)) * sin(radians(m.latitude))
        )) AS distance_meters
    FROM messages m
    JOIN users u ON m.user_id = u.id
    WHERE m.visibility = 'public'
    AND (6371000 * acos(
        cos(radians(user_lat)) * cos(radians(m.latitude)) *
        cos(radians(m.longitude) - radians(user_lng)) +
        sin(radians(user_lat)) * sin(radians(m.latitude))
    )) <= radius_meters
    ORDER BY distance_meters ASC
    LIMIT msg_limit;
END;
$$ LANGUAGE plpgsql;

-- Trigger: auto-update counters
CREATE OR REPLACE FUNCTION update_interaction_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.type = 'like' THEN
            UPDATE messages SET likes_count = likes_count + 1 WHERE id = NEW.message_id;
        ELSIF NEW.type = 'comment' THEN
            UPDATE messages SET comments_count = comments_count + 1 WHERE id = NEW.message_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.type = 'like' THEN
            UPDATE messages SET likes_count = likes_count - 1 WHERE id = OLD.message_id;
        ELSIF OLD.type = 'comment' THEN
            UPDATE messages SET comments_count = comments_count - 1 WHERE id = OLD.message_id;
        END IF;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_interaction_counts
AFTER INSERT OR DELETE ON interactions
FOR EACH ROW EXECUTE FUNCTION update_interaction_counts();
