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

type ReportRequest struct {
	Reason      string `json:"reason"`
	Description string `json:"description"`
}

func (r ReportRequest) Validate() map[string]string {
	errs := make(map[string]string)
	validReasons := map[string]bool{
		"spam":            true,
		"harassment":      true,
		"inappropriate":   true,
		"misinformation":  true,
		"other":           true,
	}
	if r.Reason == "" {
		errs["reason"] = "raison requise"
	} else if !validReasons[r.Reason] {
		errs["reason"] = "raison invalide (spam, harassment, inappropriate, misinformation, other)"
	}
	if len(r.Description) > 500 {
		errs["description"] = "500 caracteres maximum"
	}
	return errs
}

type Reaction struct {
	ID        string    `json:"id"`
	MessageID string    `json:"message_id"`
	UserID    string    `json:"user_id"`
	Username  string    `json:"username,omitempty"`
	Emoji     string    `json:"emoji"`
	CreatedAt time.Time `json:"created_at"`
}

type ReactionRequest struct {
	Emoji string `json:"emoji"`
}

func (r ReactionRequest) Validate() map[string]string {
	errs := make(map[string]string)
	allowed := map[string]bool{
		"\u2764\uFE0F": true, // heart
		"\U0001F602":    true, // joy
		"\U0001F62E":    true, // open mouth
		"\U0001F622":    true, // cry
		"\U0001F525":    true, // fire
		"\U0001F44F":    true, // clap
	}
	if r.Emoji == "" {
		errs["emoji"] = "emoji requis"
	} else if !allowed[r.Emoji] {
		errs["emoji"] = "emoji non autorise"
	}
	return errs
}

type ReactionSummary struct {
	Emoji   string `json:"emoji"`
	Count   int    `json:"count"`
	Reacted bool   `json:"reacted"`
}

type ReactionResponse struct {
	Reacted   bool              `json:"reacted"`
	Reactions []ReactionSummary `json:"reactions"`
}
