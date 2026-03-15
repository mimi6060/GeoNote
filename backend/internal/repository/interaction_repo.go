package repository

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mimi6060/GeoNote/backend/internal/model"
)

type InteractionRepo struct {
	pool *pgxpool.Pool
}

func NewInteractionRepo(pool *pgxpool.Pool) *InteractionRepo {
	return &InteractionRepo{pool: pool}
}

func (r *InteractionRepo) ToggleLike(ctx context.Context, messageID, userID string) (*model.LikeResponse, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var existingID string
	err = tx.QueryRow(ctx,
		`SELECT id FROM interactions WHERE message_id = $1 AND user_id = $2 AND type = 'like'`,
		messageID, userID,
	).Scan(&existingID)

	liked := true
	if err == nil {
		_, err = tx.Exec(ctx, `DELETE FROM interactions WHERE id = $1`, existingID)
		if err != nil {
			return nil, err
		}
		liked = false
	} else if err == pgx.ErrNoRows {
		_, err = tx.Exec(ctx,
			`INSERT INTO interactions (message_id, user_id, type) VALUES ($1, $2, 'like')`,
			messageID, userID,
		)
		if err != nil {
			return nil, err
		}
	} else {
		return nil, err
	}

	var count int
	err = tx.QueryRow(ctx,
		`SELECT likes_count FROM messages WHERE id = $1`, messageID,
	).Scan(&count)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	return &model.LikeResponse{Liked: liked, LikesCount: count}, nil
}

func (r *InteractionRepo) AddComment(ctx context.Context, messageID, userID, content string) (*model.Interaction, error) {
	interaction := &model.Interaction{}
	err := r.pool.QueryRow(ctx,
		`INSERT INTO interactions (message_id, user_id, type, content)
		 VALUES ($1, $2, 'comment', $3)
		 RETURNING id, message_id, user_id, type, content, created_at`,
		messageID, userID, content,
	).Scan(
		&interaction.ID, &interaction.MessageID, &interaction.UserID,
		&interaction.Type, &interaction.Content, &interaction.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return interaction, nil
}

func (r *InteractionRepo) DeleteComment(ctx context.Context, commentID, userID string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM interactions WHERE id = $1 AND user_id = $2 AND type = 'comment'`,
		commentID, userID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *InteractionRepo) GetComments(ctx context.Context, messageID string) ([]model.Interaction, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT i.id, i.message_id, i.user_id, u.username, i.type, i.content, i.created_at
		 FROM interactions i
		 JOIN users u ON i.user_id = u.id
		 WHERE i.message_id = $1 AND i.type = 'comment'
		 ORDER BY i.created_at ASC`,
		messageID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var comments []model.Interaction
	for rows.Next() {
		var c model.Interaction
		if err := rows.Scan(&c.ID, &c.MessageID, &c.UserID, &c.Username, &c.Type, &c.Content, &c.CreatedAt); err != nil {
			return nil, err
		}
		comments = append(comments, c)
	}
	return comments, nil
}

func (r *InteractionRepo) ReportMessage(ctx context.Context, messageID, userID, reason, description string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO content_reports (reporter_id, message_id, reason, description) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
		userID, messageID, reason, description)
	return err
}

// GetReportCount returns the number of reports for a given message.
func (r *InteractionRepo) GetReportCount(ctx context.Context, messageID string) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM content_reports WHERE message_id = $1`,
		messageID,
	).Scan(&count)
	return count, err
}

// HideMessage marks a message as hidden (auto-moderation).
func (r *InteractionRepo) HideMessage(ctx context.Context, messageID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE messages SET is_hidden = true WHERE id = $1`,
		messageID)
	return err
}

// ToggleReaction adds or removes an emoji reaction. Returns true if the reaction was added.
func (r *InteractionRepo) ToggleReaction(ctx context.Context, messageID, userID, emoji string) (bool, error) {
	var existingID string
	err := r.pool.QueryRow(ctx,
		`SELECT id FROM reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3`,
		messageID, userID, emoji,
	).Scan(&existingID)

	if err == nil {
		// Exists — remove it
		_, err = r.pool.Exec(ctx, `DELETE FROM reactions WHERE id = $1`, existingID)
		if err != nil {
			return false, err
		}
		return false, nil
	} else if err == pgx.ErrNoRows {
		// Doesn't exist — add it
		_, err = r.pool.Exec(ctx,
			`INSERT INTO reactions (message_id, user_id, emoji) VALUES ($1, $2, $3)`,
			messageID, userID, emoji,
		)
		if err != nil {
			return false, err
		}
		return true, nil
	}
	return false, err
}

// GetReactionsByMessage returns the count per emoji and whether the given user reacted.
func (r *InteractionRepo) GetReactionsByMessage(ctx context.Context, messageID, userID string) ([]model.ReactionSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT r.emoji, COUNT(*) AS cnt,
		        BOOL_OR(r.user_id = $2) AS reacted
		 FROM reactions r
		 WHERE r.message_id = $1
		 GROUP BY r.emoji
		 ORDER BY cnt DESC`,
		messageID, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var summaries []model.ReactionSummary
	for rows.Next() {
		var s model.ReactionSummary
		if err := rows.Scan(&s.Emoji, &s.Count, &s.Reacted); err != nil {
			return nil, err
		}
		summaries = append(summaries, s)
	}
	return summaries, nil
}

// GetReactionsByMessages returns reaction summaries for multiple messages at once (batch).
func (r *InteractionRepo) GetReactionsByMessages(ctx context.Context, messageIDs []string, userID string) (map[string][]model.ReactionSummary, error) {
	if len(messageIDs) == 0 {
		return nil, nil
	}

	rows, err := r.pool.Query(ctx,
		`SELECT r.message_id, r.emoji, COUNT(*) AS cnt,
		        BOOL_OR(r.user_id = $2) AS reacted
		 FROM reactions r
		 WHERE r.message_id = ANY($1)
		 GROUP BY r.message_id, r.emoji
		 ORDER BY r.message_id, cnt DESC`,
		messageIDs, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[string][]model.ReactionSummary)
	for rows.Next() {
		var msgID string
		var s model.ReactionSummary
		if err := rows.Scan(&msgID, &s.Emoji, &s.Count, &s.Reacted); err != nil {
			return nil, err
		}
		result[msgID] = append(result[msgID], s)
	}
	return result, nil
}
