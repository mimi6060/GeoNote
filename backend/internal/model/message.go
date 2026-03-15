package model

import "time"

type Message struct {
	ID            string     `json:"id"`
	UserID        string     `json:"user_id"`
	Username      string     `json:"username"`
	Content       string     `json:"content"`
	Latitude      float64    `json:"latitude"`
	Longitude     float64    `json:"longitude"`
	Visibility    string     `json:"visibility"`
	Hashtags      []string   `json:"hashtags"`
	LikesCount    int        `json:"likes_count"`
	CommentsCount int        `json:"comments_count"`
	Distance      *float64   `json:"distance_meters,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	MessageType   string     `json:"message_type"`
	ExpiresAt     *time.Time `json:"expires_at,omitempty"`
	MysteryRadius int        `json:"mystery_radius,omitempty"`
	ScheduledAt   *time.Time `json:"scheduled_at,omitempty"`
	UnlocksCount  int               `json:"unlocks_count,omitempty"`
	Reactions     []ReactionSummary `json:"reactions,omitempty"`
}

type CreateMessageRequest struct {
	Content       string  `json:"content"`
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
	Visibility    string  `json:"visibility"`
	MessageType   string  `json:"message_type"`
	MysteryRadius int     `json:"mystery_radius,omitempty"`
	ScheduledAt   string  `json:"scheduled_at,omitempty"` // RFC3339
}

func (r CreateMessageRequest) Validate() map[string]string {
	errs := make(map[string]string)
	if r.Content == "" || len(r.Content) > 500 {
		errs["content"] = "entre 1 et 500 caracteres"
	}
	if r.Latitude < -90 || r.Latitude > 90 {
		errs["latitude"] = "doit etre entre -90 et 90"
	}
	if r.Longitude < -180 || r.Longitude > 180 {
		errs["longitude"] = "doit etre entre -180 et 180"
	}
	switch r.Visibility {
	case "public", "friends", "private", "":
	default:
		errs["visibility"] = "public, friends ou private"
	}
	switch r.MessageType {
	case "standard", "mystery", "capsule", "":
	default:
		errs["message_type"] = "standard, mystery ou capsule"
	}
	if r.MessageType == "mystery" && r.MysteryRadius > 500 {
		errs["mystery_radius"] = "max 500 metres"
	}
	if r.MessageType == "capsule" && r.ScheduledAt == "" {
		errs["scheduled_at"] = "date requise pour une capsule"
	}
	return errs
}

type NearbyQuery struct {
	Latitude  float64
	Longitude float64
	Radius    int
	Limit     int
	Sort      string
	Hashtag   string
	UserID    string
}

type HeatmapPoint struct {
	Lat       float64 `json:"lat"`
	Lng       float64 `json:"lng"`
	Intensity int     `json:"intensity"`
}

type LeaderboardEntry struct {
	UserID     string `json:"user_id"`
	Username   string `json:"username"`
	TotalPosts int64  `json:"total_posts"`
	TotalLikes int64  `json:"total_likes"`
	Score      int64  `json:"score"`
}

type UserStreak struct {
	UserID        string `json:"user_id"`
	CurrentStreak int    `json:"current_streak"`
	MaxStreak     int    `json:"max_streak"`
	TotalPosts    int    `json:"total_posts"`
	TotalZones    int    `json:"total_zones"`
	TotalUnlocks  int    `json:"total_unlocks"`
}

type Badge struct {
	ID        string    `json:"id"`
	BadgeType string    `json:"badge_type"`
	EarnedAt  time.Time `json:"earned_at"`
}

type Event struct {
	GridLat        float64   `json:"grid_lat"`
	GridLng        float64   `json:"grid_lng"`
	MessageCount   int64     `json:"message_count"`
	UserCount      int64     `json:"user_count"`
	FirstMessageAt time.Time `json:"first_message_at"`
	LastMessageAt  time.Time `json:"last_message_at"`
	TopHashtags    []string  `json:"top_hashtags"`
}
