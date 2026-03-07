package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/mimi6060/GeoNote/backend/internal/handler"
	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type contextKey string

const UserIDKey contextKey = "user_id"

// Auth verifie le token JWT et injecte le user_id dans le contexte.
func Auth(authSvc *service.AuthService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if header == "" {
				handler.WriteError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "Token requis")
				return
			}

			token := strings.TrimPrefix(header, "Bearer ")
			if token == header {
				handler.WriteError(w, http.StatusUnauthorized, "AUTH_INVALID", "Format: Bearer <token>")
				return
			}

			userID, err := authSvc.ValidateToken(token)
			if err != nil {
				handler.WriteError(w, http.StatusUnauthorized, "AUTH_INVALID", "Token invalide")
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
