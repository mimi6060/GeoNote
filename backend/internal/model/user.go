package model

import "time"

type User struct {
	ID           string    `json:"id"`
	Username     string    `json:"username"`
	Email        string    `json:"email,omitempty"`
	PasswordHash string    `json:"-"`
	AvatarURL    *string   `json:"avatar_url,omitempty"`
	IsAnonymous  bool      `json:"is_anonymous"`
	CreatedAt    time.Time `json:"created_at"`
}

type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (r RegisterRequest) Validate() map[string]string {
	errs := make(map[string]string)
	if len(r.Username) < 3 || len(r.Username) > 30 {
		errs["username"] = "doit contenir entre 3 et 30 caracteres"
	}
	if r.Email == "" {
		errs["email"] = "requis"
	}
	if len(r.Password) < 8 {
		errs["password"] = "8 caracteres minimum"
	}
	return errs
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (r LoginRequest) Validate() map[string]string {
	errs := make(map[string]string)
	if r.Email == "" {
		errs["email"] = "requis"
	}
	if r.Password == "" {
		errs["password"] = "requis"
	}
	return errs
}

type AuthResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}
