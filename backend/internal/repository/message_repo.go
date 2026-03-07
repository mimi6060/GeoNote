package repository

import (
	"context"
	"regexp"
	"strings"

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

	msg := &model.Message{}
	err := r.pool.QueryRow(ctx,
		`WITH ins AS (
		   INSERT INTO messages (user_id, content, latitude, longitude, visibility, hashtags)
		   VALUES ($1, $2, $3, $4, $5, $6)
		   RETURNING *
		 )
		 SELECT ins.id, ins.user_id, u.username, ins.content, ins.latitude, ins.longitude,
		        ins.visibility, ins.hashtags, ins.likes_count, ins.comments_count, ins.created_at
		 FROM ins JOIN users u ON ins.user_id = u.id`,
		userID, strings.TrimSpace(req.Content), req.Latitude, req.Longitude, vis, hashtags,
	).Scan(
		&msg.ID, &msg.UserID, &msg.Username, &msg.Content, &msg.Latitude, &msg.Longitude,
		&msg.Visibility, &msg.Hashtags, &msg.LikesCount, &msg.CommentsCount, &msg.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return msg, nil
}

func (r *MessageRepo) GetNearby(ctx context.Context, q model.NearbyQuery) ([]model.Message, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, user_id, username, content, latitude, longitude,
		        visibility, hashtags, likes_count, comments_count, created_at, distance_meters
		 FROM get_nearby_messages($1, $2, $3, $4)`,
		q.Latitude, q.Longitude, q.Radius, q.Limit,
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
		`DELETE FROM messages WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
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
		`SELECT m.id, m.user_id, u.username, m.content, m.latitude, m.longitude,
		        m.visibility, m.hashtags, m.likes_count, m.comments_count, m.created_at
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
		); err != nil {
			return nil, err
		}
		messages = append(messages, m)
	}
	return messages, nil
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
