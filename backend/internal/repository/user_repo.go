package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mimi6060/GeoNote/backend/internal/model"
)

type UserRepo struct {
	pool *pgxpool.Pool
}

func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool}
}

func (r *UserRepo) Create(ctx context.Context, user *model.User) error {
	return r.pool.QueryRow(ctx,
		`INSERT INTO users (username, email, password_hash)
		 VALUES ($1, $2, $3)
		 RETURNING id, created_at`,
		user.Username, user.Email, user.PasswordHash,
	).Scan(&user.ID, &user.CreatedAt)
}

func (r *UserRepo) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	u := &model.User{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, username, email, password_hash, avatar_url, is_anonymous, created_at
		 FROM users WHERE email = $1`,
		email,
	).Scan(&u.ID, &u.Username, &u.Email, &u.PasswordHash, &u.AvatarURL, &u.IsAnonymous, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return u, nil
}

func (r *UserRepo) GetByID(ctx context.Context, id string) (*model.User, error) {
	u := &model.User{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, username, email, avatar_url, is_anonymous, created_at
		 FROM users WHERE id = $1`,
		id,
	).Scan(&u.ID, &u.Username, &u.Email, &u.AvatarURL, &u.IsAnonymous, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return u, nil
}

// SearchByUsername searches users by username with ILIKE pattern matching.
func (r *UserRepo) SearchByUsername(ctx context.Context, query string, limit, offset int) ([]model.UserSummary, int, error) {
	pattern := "%" + query + "%"

	// Get total count
	var total int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM users WHERE username ILIKE $1`,
		pattern,
	).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	// Get paginated results
	rows, err := r.pool.Query(ctx,
		`SELECT id, username FROM users
		 WHERE username ILIKE $1
		 ORDER BY username ASC
		 LIMIT $2 OFFSET $3`,
		pattern, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var users []model.UserSummary
	for rows.Next() {
		var u model.UserSummary
		if err := rows.Scan(&u.ID, &u.Username); err != nil {
			return nil, 0, err
		}
		users = append(users, u)
	}
	return users, total, nil
}
