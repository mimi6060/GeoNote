CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Utilisateurs
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL DEFAULT '',
    avatar_url TEXT,
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_]{3,30}$')
);

-- Messages geolocalises
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    visibility VARCHAR(10) NOT NULL DEFAULT 'public',
    hashtags TEXT[] DEFAULT '{}',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT content_not_empty CHECK (char_length(content) > 0),
    CONSTRAINT content_max_length CHECK (char_length(content) <= 500),
    CONSTRAINT valid_visibility CHECK (visibility IN ('public', 'friends', 'private'))
);

CREATE INDEX idx_messages_user_id ON messages(user_id);
CREATE INDEX idx_messages_location ON messages USING GIST(location);
CREATE INDEX idx_messages_visibility ON messages(visibility);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX idx_messages_hashtags ON messages USING GIN(hashtags);

-- Interactions (likes + commentaires)
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
    )
);

CREATE INDEX idx_interactions_message_id ON interactions(message_id);
CREATE INDEX idx_interactions_user_id ON interactions(user_id);
CREATE UNIQUE INDEX one_like_per_user_per_message ON interactions(message_id, user_id) WHERE type = 'like';

-- Inscriptions beta
CREATE TABLE beta_signups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Recherche par proximite avec PostGIS
-- Bounding box pre-filter + ST_DWithin pour performance optimale
CREATE OR REPLACE FUNCTION get_nearby_messages(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters INTEGER DEFAULT 500,
    msg_limit INTEGER DEFAULT 50,
    current_user_id UUID DEFAULT NULL
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
DECLARE
    delta_lat DOUBLE PRECISION := (radius_meters::DOUBLE PRECISION / 111000.0) * 1.2;
    delta_lng DOUBLE PRECISION := (radius_meters::DOUBLE PRECISION / (111000.0 * COS(RADIANS(user_lat)))) * 1.2;
    user_point GEOMETRY := ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326);
BEGIN
    RETURN QUERY
    SELECT
        m.id, m.user_id, u.username, m.content,
        ST_Y(m.location) AS latitude,
        ST_X(m.location) AS longitude,
        m.visibility, m.hashtags,
        m.likes_count, m.comments_count, m.created_at,
        ST_Distance(m.location::geography, user_point::geography) AS distance_meters
    FROM messages m
    JOIN users u ON m.user_id = u.id
    WHERE
        m.location && ST_MakeEnvelope(
            user_lng - delta_lng, user_lat - delta_lat,
            user_lng + delta_lng, user_lat + delta_lat,
            4326
        )
        AND ST_DWithin(m.location::geography, user_point::geography, radius_meters)
        AND (
            m.visibility = 'public'
            OR (current_user_id IS NOT NULL AND m.user_id = current_user_id)
        )
    ORDER BY distance_meters ASC
    LIMIT msg_limit;
END;
$$ LANGUAGE plpgsql;

-- Trigger: mise a jour automatique des compteurs
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
