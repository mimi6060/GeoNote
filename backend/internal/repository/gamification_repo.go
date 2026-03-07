package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mimi6060/GeoNote/backend/internal/model"
)

type GamificationRepo struct {
	pool *pgxpool.Pool
}

func NewGamificationRepo(pool *pgxpool.Pool) *GamificationRepo {
	return &GamificationRepo{pool: pool}
}

// GetStreak returns the user's streak data.
func (r *GamificationRepo) GetStreak(ctx context.Context, userID string) (*model.UserStreak, error) {
	s := &model.UserStreak{UserID: userID}
	err := r.pool.QueryRow(ctx,
		`SELECT current_streak, max_streak, total_posts, total_zones, total_unlocks
		 FROM user_streaks WHERE user_id = $1`, userID,
	).Scan(&s.CurrentStreak, &s.MaxStreak, &s.TotalPosts, &s.TotalZones, &s.TotalUnlocks)
	if err != nil {
		// Return zero streak if not found
		return &model.UserStreak{UserID: userID}, nil
	}
	return s, nil
}

// RecordPost updates the user's streak after posting.
func (r *GamificationRepo) RecordPost(ctx context.Context, userID string, lat, lng float64) error {
	// Upsert streak: if last_post_date is today, just increment total_posts.
	// If yesterday, increment streak. Otherwise reset to 1.
	_, err := r.pool.Exec(ctx, `
		INSERT INTO user_streaks (user_id, current_streak, max_streak, last_post_date, total_posts, total_zones)
		VALUES ($1, 1, 1, CURRENT_DATE, 1,
			(SELECT COUNT(DISTINCT (ROUND(ST_Y(location)::numeric,2)||','||ROUND(ST_X(location)::numeric,2)))
			 FROM messages WHERE user_id = $1)
		)
		ON CONFLICT (user_id) DO UPDATE SET
			current_streak = CASE
				WHEN user_streaks.last_post_date = CURRENT_DATE THEN user_streaks.current_streak
				WHEN user_streaks.last_post_date = CURRENT_DATE - 1 THEN user_streaks.current_streak + 1
				ELSE 1
			END,
			max_streak = GREATEST(user_streaks.max_streak, CASE
				WHEN user_streaks.last_post_date = CURRENT_DATE THEN user_streaks.current_streak
				WHEN user_streaks.last_post_date = CURRENT_DATE - 1 THEN user_streaks.current_streak + 1
				ELSE 1
			END),
			last_post_date = CURRENT_DATE,
			total_posts = user_streaks.total_posts + 1,
			total_zones = (SELECT COUNT(DISTINCT (ROUND(ST_Y(location)::numeric,2)||','||ROUND(ST_X(location)::numeric,2)))
			               FROM messages WHERE user_id = $1),
			updated_at = NOW()
	`, userID)
	return err
}

// RecordUnlock increments the user's total_unlocks.
func (r *GamificationRepo) RecordUnlock(ctx context.Context, userID string) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO user_streaks (user_id, total_unlocks)
		VALUES ($1, 1)
		ON CONFLICT (user_id) DO UPDATE SET
			total_unlocks = user_streaks.total_unlocks + 1,
			updated_at = NOW()
	`, userID)
	return err
}

// GetBadges returns all badges for a user.
func (r *GamificationRepo) GetBadges(ctx context.Context, userID string) ([]model.Badge, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, badge_type, earned_at FROM user_badges WHERE user_id = $1 ORDER BY earned_at DESC`,
		userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var badges []model.Badge
	for rows.Next() {
		var b model.Badge
		if err := rows.Scan(&b.ID, &b.BadgeType, &b.EarnedAt); err != nil {
			return nil, err
		}
		badges = append(badges, b)
	}
	return badges, nil
}

// AwardBadge gives a badge to a user (idempotent).
func (r *GamificationRepo) AwardBadge(ctx context.Context, userID, badgeType string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_badges (user_id, badge_type) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		userID, badgeType)
	return err
}

// CheckAndAwardBadges evaluates streaks/stats and awards earned badges.
func (r *GamificationRepo) CheckAndAwardBadges(ctx context.Context, userID string) error {
	s, err := r.GetStreak(ctx, userID)
	if err != nil {
		return err
	}

	// Post milestones
	if s.TotalPosts >= 1 {
		r.AwardBadge(ctx, userID, "first_post")
	}

	// Explorer badges
	if s.TotalZones >= 5 {
		r.AwardBadge(ctx, userID, "explorer_5")
	}
	if s.TotalZones >= 10 {
		r.AwardBadge(ctx, userID, "explorer_10")
	}
	if s.TotalZones >= 25 {
		r.AwardBadge(ctx, userID, "explorer_25")
	}

	// Streak badges
	if s.CurrentStreak >= 3 {
		r.AwardBadge(ctx, userID, "streak_3")
	}
	if s.CurrentStreak >= 7 {
		r.AwardBadge(ctx, userID, "streak_7")
	}
	if s.CurrentStreak >= 30 {
		r.AwardBadge(ctx, userID, "streak_30")
	}

	// Mystery hunter
	if s.TotalUnlocks >= 5 {
		r.AwardBadge(ctx, userID, "mystery_hunter_5")
	}
	if s.TotalUnlocks >= 25 {
		r.AwardBadge(ctx, userID, "mystery_hunter_25")
	}

	return nil
}
