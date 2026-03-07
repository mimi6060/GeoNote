package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mimi6060/GeoNote/backend/internal/cache"
	"github.com/mimi6060/GeoNote/backend/internal/config"
	"github.com/mimi6060/GeoNote/backend/internal/handler"
	"github.com/mimi6060/GeoNote/backend/internal/middleware"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
	"github.com/mimi6060/GeoNote/backend/internal/service"
	"github.com/mimi6060/GeoNote/backend/internal/ws"
)

func main() {
	cfg := config.Load()

	// ---- Database (PostgreSQL + PostGIS) ----
	pool, err := pgxpool.New(context.Background(), cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connexion DB impossible: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(context.Background()); err != nil {
		log.Fatalf("ping DB echoue: %v", err)
	}
	log.Println("connecte a PostgreSQL + PostGIS")

	// ---- Redis Cache ----
	redisCache := cache.NewRedisCache(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB, cfg.CacheTTL)
	defer redisCache.Close()

	// ---- WebSocket Hub ----
	hub := ws.NewHub()

	// ---- Repositories ----
	userRepo := repository.NewUserRepo(pool)
	messageRepo := repository.NewMessageRepo(pool)
	interactionRepo := repository.NewInteractionRepo(pool)
	gamRepo := repository.NewGamificationRepo(pool)

	// ---- Services ----
	authSvc := service.NewAuthService(userRepo, cfg.JWTSecret, cfg.JWTExpiry)
	messageSvc := service.NewMessageService(messageRepo, gamRepo, redisCache, hub)
	interactionSvc := service.NewInteractionService(interactionRepo)
	gamSvc := service.NewGamificationService(gamRepo)

	// ---- Handlers ----
	authH := handler.NewAuthHandler(authSvc)
	messageH := handler.NewMessageHandler(messageSvc)
	interactionH := handler.NewInteractionHandler(interactionSvc)
	gamH := handler.NewGamificationHandler(gamSvc)

	// ---- Router ----
	r := chi.NewRouter()

	// Middlewares globaux
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))
	r.Use(chimw.RealIP)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))
	r.Use(middleware.RateLimit(10, 20)) // 10 req/s, burst 20

	// ---- Routes ----
	r.Route("/api/v1", func(r chi.Router) {
		// Health
		r.Get("/health", handler.HealthCheck(pool))

		// Auth (public)
		r.Post("/auth/register", authH.Register)
		r.Post("/auth/login", authH.Login)

		// Public routes with optional auth
		r.Group(func(r chi.Router) {
			r.Use(middleware.OptionalAuth(authSvc))

			r.Get("/messages/nearby", messageH.GetNearby)
			r.Get("/heatmap", messageH.GetHeatmap)
			r.Get("/leaderboard", messageH.GetLeaderboard)
		})
		r.Get("/users/{id}/messages", messageH.GetByUser)
		r.Get("/users/{id}/profile", gamH.GetUserProfile)

		// Authenticated routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(authSvc))

			r.Get("/auth/me", authH.Me)
			r.Get("/me/profile", gamH.GetMyProfile)

			r.With(middleware.AntiSpam(30 * time.Second)).Post("/messages", messageH.Create)
			r.Delete("/messages/{id}", messageH.Delete)
			r.Post("/messages/{id}/unlock", messageH.UnlockMystery)

			r.Post("/messages/{id}/like", interactionH.ToggleLike)
			r.Post("/messages/{id}/comments", interactionH.AddComment)
			r.Delete("/comments/{commentId}", interactionH.DeleteComment)
		})

		// Comments (public read)
		r.Get("/messages/{id}/comments", interactionH.GetComments)
	})

	// WebSocket
	r.Get("/ws", func(w http.ResponseWriter, r *http.Request) {
		ws.ServeWS(hub, w, r)
	})

	// ---- Server ----
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf("GeoNote API sur http://localhost:%s", cfg.Port)
		log.Printf("WebSocket sur ws://localhost:%s/ws", cfg.Port)
		if err := srv.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("erreur serveur: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("arret en cours...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("arret force: %v", err)
	}
	log.Println("serveur arrete")
}
