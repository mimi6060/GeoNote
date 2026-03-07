package repository

import (
	"context"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mimi6060/GeoNote/backend/internal/model"
)

var hashtagRe = regexp.MustCompile(`#([a-zA-Z0-9_]+)`)

type MessageRepo struct {
	pool *pgxpool.Pool
}

func NewMessageRepo(pool *pgxpool.Pool) *MessageRepo {
	return &MessageRepo{pool: pool}
}

func (r *MessageRepo) Create(ctx context.Context, userID string, req model.CreateMessageRequest) (*model.Message, error) {
	hashtags := extractHashtags(req.Content)
	vis := req.Visibility
	if vis == "" {
		vis = "public"
	}
	msgType := req.MessageType
	if msgType == "" {
		msgType = "standard"
	}
	mysteryRadius := req.MysteryRadius
	if mysteryRadius <= 0 {
		mysteryRadius = 50
	}

	// Compute expiry
	var expiresAt *time.Time
	switch msgType {
	case "standard":
		t := time.Now().Add(24 * time.Hour)
		expiresAt = &t
	case "capsule":
		// Capsule expires 24h after scheduled reveal
		if scheduled, err := time.Parse(time.RFC3339, req.ScheduledAt); err == nil {
			t := scheduled.Add(24 * time.Hour)
			expiresAt = &t
		}
	}
	// Mystery messages don't auto-expire

	var scheduledAt *time.Time
	if msgType == "capsule" && req.ScheduledAt != "" {
		if t, err := time.Parse(time.RFC3339, req.ScheduledAt); err == nil {
			scheduledAt = &t
		}
	}

	msg := &model.Message{}
	err := r.pool.QueryRow(ctx,
		`WITH ins AS (
		   INSERT INTO messages (user_id, content, location, visibility, hashtags,
		                         message_type, expires_at, mystery_radius, scheduled_at)
		   VALUES ($1, $2, ST_SetSRID(ST_MakePoint($4, $3), 4326), $5, $6, $7, $8, $9, $10)
		   RETURNING *
		 )
		 SELECT ins.id, ins.user_id, u.username, ins.content,
		        ST_Y(ins.location) AS latitude, ST_X(ins.location) AS longitude,
		        ins.visibility, ins.hashtags, ins.likes_count, ins.comments_count, ins.created_at,
		        ins.message_type, ins.expires_at, ins.mystery_radius, ins.scheduled_at, ins.unlocks_count
		 FROM ins JOIN users u ON ins.user_id = u.id`,
		userID, strings.TrimSpace(req.Content), req.Latitude, req.Longitude, vis, hashtags,
		msgType, expiresAt, mysteryRadius, scheduledAt,
	).Scan(
		&msg.ID, &msg.UserID, &msg.Username, &msg.Content, &msg.Latitude, &msg.Longitude,
		&msg.Visibility, &msg.Hashtags, &msg.LikesCount, &msg.CommentsCount, &msg.CreatedAt,
		&msg.MessageType, &msg.ExpiresAt, &msg.MysteryRadius, &msg.ScheduledAt, &msg.UnlocksCount,
	)
	if err != nil {
		return nil, err
	}
	return msg, nil
}

func (r *MessageRepo) GetNearby(ctx context.Context, q model.NearbyQuery) ([]model.Message, error) {
	var userIDParam interface{}
	if q.UserID != "" {
		userIDParam = q.UserID
	}

	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, username, content, latitude, longitude,
		        visibility, hashtags, likes_count, comments_count, created_at, distance_meters,
		        message_type, expires_at, mystery_radius, scheduled_at, unlocks_count
		 FROM get_nearby_messages($1, $2, $3, $4, $5)`,
		q.Latitude, q.Longitude, q.Radius, q.Limit, userIDParam,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []model.Message
	for rows.Next() {
		var m model.Message
		var dist float64
		if err := rows.Scan(
			&m.ID, &m.UserID, &m.Username, &m.Content,
			&m.Latitude, &m.Longitude, &m.Visibility, &m.Hashtags,
			&m.LikesCount, &m.CommentsCount, &m.CreatedAt, &dist,
			&m.MessageType, &m.ExpiresAt, &m.MysteryRadius, &m.ScheduledAt, &m.UnlocksCount,
		); err != nil {
			return nil, err
		}
		m.Distance = &dist
		messages = append(messages, m)
	}

	if q.Hashtag != "" {
		tag := strings.ToLower(strings.TrimPrefix(q.Hashtag, "#"))
		filtered := messages[:0]
		for _, m := range messages {
			for _, h := range m.Hashtags {
				if strings.Contains(strings.ToLower(h), tag) {
					filtered = append(filtered, m)
					break
				}
			}
		}
		messages = filtered
	}

	return messages, nil
}

func (r *MessageRepo) Delete(ctx context.Context, id, userID string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM messages WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *MessageRepo) GetByUser(ctx context.Context, userID string) ([]model.Message, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT m.id, m.user_id, u.username, m.content,
		        ST_Y(m.location) AS latitude, ST_X(m.location) AS longitude,
		        m.visibility, m.hashtags, m.likes_count, m.comments_count, m.created_at,
		        m.message_type, m.expires_at, m.mystery_radius, m.scheduled_at, m.unlocks_count
		 FROM messages m
		 JOIN users u ON m.user_id = u.id
		 WHERE m.user_id = $1
		 ORDER BY m.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []model.Message
	for rows.Next() {
		var m model.Message
		if err := rows.Scan(
			&m.ID, &m.UserID, &m.Username, &m.Content,
			&m.Latitude, &m.Longitude, &m.Visibility, &m.Hashtags,
			&m.LikesCount, &m.CommentsCount, &m.CreatedAt,
			&m.MessageType, &m.ExpiresAt, &m.MysteryRadius, &m.ScheduledAt, &m.UnlocksCount,
		); err != nil {
			return nil, err
		}
		messages = append(messages, m)
	}
	return messages, nil
}

// UnlockMystery records that a user unlocked a mystery message. Returns true if newly unlocked.
func (r *MessageRepo) UnlockMystery(ctx context.Context, messageID, userID string) (bool, error) {
	result, err := r.pool.Exec(ctx,
		`INSERT INTO message_unlocks (message_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		messageID, userID)
	if err != nil {
		return false, err
	}
	return result.RowsAffected() > 0, nil
}

// IsUnlocked checks if a user has unlocked a mystery message.
func (r *MessageRepo) IsUnlocked(ctx context.Context, messageID, userID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM message_unlocks WHERE message_id = $1 AND user_id = $2)`,
		messageID, userID).Scan(&exists)
	return exists, err
}

// GetHeatmap returns aggregated activity points.
func (r *MessageRepo) GetHeatmap(ctx context.Context, lat, lng float64, radius int) ([]model.HeatmapPoint, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT grid_lat, grid_lng, intensity FROM get_heatmap($1, $2, $3)`,
		lat, lng, radius)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var points []model.HeatmapPoint
	for rows.Next() {
		var p model.HeatmapPoint
		if err := rows.Scan(&p.Lat, &p.Lng, &p.Intensity); err != nil {
			return nil, err
		}
		points = append(points, p)
	}
	return points, nil
}

// GetLeaderboard returns local rankings.
func (r *MessageRepo) GetLeaderboard(ctx context.Context, lat, lng float64, radius, limit int) ([]model.LeaderboardEntry, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT user_id, username, total_posts, total_likes, score FROM get_leaderboard($1, $2, $3, $4)`,
		lat, lng, radius, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []model.LeaderboardEntry
	for rows.Next() {
		var e model.LeaderboardEntry
		if err := rows.Scan(&e.UserID, &e.Username, &e.TotalPosts, &e.TotalLikes, &e.Score); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, nil
}

func extractHashtags(content string) []string {
	matches := hashtagRe.FindAllStringSubmatch(content, -1)
	seen := make(map[string]bool)
	var tags []string
	for _, m := range matches {
		tag := strings.ToLower(m[1])
		if !seen[tag] {
			seen[tag] = true
			tags = append(tags, tag)
		}
	}
	return tags
}
