package model

import "time"

type Message struct {
	ID            string    `json:"id"`
	UserID        string    `json:"user_id"`
	Username      string    `json:"username"`
	Content       string    `json:"content"`
	Latitude      float64   `json:"latitude"`
	Longitude     float64   `json:"longitude"`
	Visibility    string    `json:"visibility"`
	Hashtags      []string  `json:"hashtags"`
	LikesCount    int       `json:"likes_count"`
	CommentsCount int       `json:"comments_count"`
	Distance      *float64  `json:"distance_meters,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

type CreateMessageRequest struct {
	Content    string  `json:"content"`
	Latitude   float64 `json:"latitude"`
	Longitude  float64 `json:"longitude"`
	Visibility string  `json:"visibility"`
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
	return errs
}

type NearbyQuery struct {
	Latitude  float64
	Longitude float64
	Radius    int
	Limit     int
	Sort      string
	Hashtag   string
}
