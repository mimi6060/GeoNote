package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func HealthCheck(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()

		err := pool.Ping(ctx)
		if err != nil {
			WriteError(w, http.StatusServiceUnavailable, "DB_DOWN", "Base de donnees inaccessible")
			return
		}

		WriteJSON(w, http.StatusOK, map[string]string{
			"status": "ok",
			"db":     "connected",
		})
	}
}
