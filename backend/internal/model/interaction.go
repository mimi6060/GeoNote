package model

import "time"

type Interaction struct {
	ID        string    `json:"id"`
	MessageID string    `json:"message_id"`
	UserID    string    `json:"user_id"`
	Username  string    `json:"username,omitempty"`
	Type      string    `json:"type"`
	Content   *string   `json:"content,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateCommentRequest struct {
	Content string `json:"content"`
}

func (r CreateCommentRequest) Validate() map[string]string {
	errs := make(map[string]string)
	if r.Content == "" || len(r.Content) > 300 {
		errs["content"] = "entre 1 et 300 caracteres"
	}
	return errs
}

type LikeResponse struct {
	Liked      bool `json:"liked"`
	LikesCount int  `json:"likes_count"`
}
