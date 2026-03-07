package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type contextKey string

const UserIDKey contextKey = "user_id"

func authError(w http.ResponseWriter, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": false,
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}

// Auth verifie le token JWT et injecte le user_id dans le contexte.
func Auth(authSvc *service.AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if header == "" {
				authError(w, "AUTH_REQUIRED", "Token requis")
				return
			}

			token := strings.TrimPrefix(header, "Bearer ")
			if token == header {
				authError(w, "AUTH_INVALID", "Format: Bearer <token>")
				return
			}

			userID, err := authSvc.ValidateToken(token)
			if err != nil {
				authError(w, "AUTH_INVALID", "Token invalide")
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetUserID extrait le user_id du contexte.
func GetUserID(ctx context.Context) string {
	if v, ok := ctx.Value(UserIDKey).(string); ok {
		return v
	}
	return ""
}
