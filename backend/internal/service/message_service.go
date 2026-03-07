package service

import (
	"context"
	"log"
	"math"
	"sort"
	"time"

	"github.com/mimi6060/GeoNote/backend/internal/cache"
	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
	"github.com/mimi6060/GeoNote/backend/internal/ws"
)

type MessageService struct {
	repo  *repository.MessageRepo
	cache *cache.RedisCache
	hub   *ws.Hub
}

func NewMessageService(repo *repository.MessageRepo, c *cache.RedisCache, hub *ws.Hub) *MessageService {
	return &MessageService{repo: repo, cache: c, hub: hub}
}

func (s *MessageService) Create(ctx context.Context, userID string, req model.CreateMessageRequest) (*model.Message, error) {
	msg, err := s.repo.Create(ctx, userID, req)
	if err != nil {
		return nil, err
	}

	s.cache.InvalidateZone(ctx)
	s.hub.BroadcastNewMessage(msg)

	return msg, nil
}

func (s *MessageService) GetNearby(ctx context.Context, q model.NearbyQuery) ([]model.Message, error) {
	if q.Radius <= 0 {
		q.Radius = 1000
	}
	if q.Limit <= 0 || q.Limit > 50 {
		q.Limit = 50
	}

	// Grid cache — only for default sort without hashtag filter
	if q.Hashtag == "" && (q.Sort == "" || q.Sort == "distance") {
		key := cache.GridKey(q.Latitude, q.Longitude, q.Radius, q.UserID)
		var cached []model.Message
		if err := s.cache.Get(ctx, key, &cached); err == nil {
			log.Printf("[cache] HIT %s (%d messages)", key, len(cached))
			return cached, nil
		}
	}

	messages, err := s.repo.GetNearby(ctx, q)
	if err != nil {
		return nil, err
	}

	// Ranking: score = distance_weight + likes_weight + recency_weight
	switch q.Sort {
	case "recent":
		sort.Slice(messages, func(i, j int) bool {
			return messages[i].CreatedAt.After(messages[j].CreatedAt)
		})
	case "popular":
		sort.Slice(messages, func(i, j int) bool {
			return messages[i].LikesCount > messages[j].LikesCount
		})
	default:
		// Ranked sort: combines distance, likes, and recency
		now := time.Now()
		sort.Slice(messages, func(i, j int) bool {
			return rankScore(&messages[i], now) > rankScore(&messages[j], now)
		})
	}

	// Grid cache store
	if q.Hashtag == "" && (q.Sort == "" || q.Sort == "distance") {
		key := cache.GridKey(q.Latitude, q.Longitude, q.Radius, q.UserID)
		if err := s.cache.Set(ctx, key, messages); err != nil {
			log.Printf("[cache] erreur SET: %v", err)
		}
	}

	return messages, nil
}

// rankScore computes a relevance score: closer + more liked + more recent = higher.
func rankScore(m *model.Message, now time.Time) float64 {
	dist := 1000.0
	if m.Distance != nil && *m.Distance > 0 {
		dist = *m.Distance
	}

	// Distance: closer = higher score (inverse, capped at 1000m)
	distScore := 1.0 - math.Min(dist, 1000.0)/1000.0

	// Likes: log scale to dampen outliers
	likesScore := math.Log1p(float64(m.LikesCount)) / 5.0

	// Recency: exponential decay, half-life = 6 hours
	hours := now.Sub(m.CreatedAt).Hours()
	recencyScore := math.Exp(-hours / 8.66) // ln(2)/8.66 ~ 6h half-life

	return distScore*0.4 + likesScore*0.3 + recencyScore*0.3
}

func (s *MessageService) Delete(ctx context.Context, id, userID string) error {
	err := s.repo.Delete(ctx, id, userID)
	if err != nil {
		return err
	}
	s.cache.InvalidateZone(ctx)
	return nil
}

func (s *MessageService) GetByUser(ctx context.Context, userID string) ([]model.Message, error) {
	return s.repo.GetByUser(ctx, userID)
}
