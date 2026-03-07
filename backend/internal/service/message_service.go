package service

import (
	"context"
	"log"
	"sort"

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

	// Invalider le cache des zones proches
	s.cache.InvalidateZone(ctx)

	// Notifier les clients WebSocket
	s.hub.BroadcastNewMessage(msg)

	return msg, nil
}

func (s *MessageService) GetNearby(ctx context.Context, q model.NearbyQuery) ([]model.Message, error) {
	if q.Radius <= 0 {
		q.Radius = 10000
	}
	if q.Limit <= 0 || q.Limit > 100 {
		q.Limit = 50
	}

	// Essayer le cache Redis (seulement pour les requetes sans hashtag et tri par distance)
	if q.Hashtag == "" && (q.Sort == "" || q.Sort == "distance") {
		key := cache.NearbyKey(q.Latitude, q.Longitude, q.Radius)
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

	switch q.Sort {
	case "recent":
		sort.Slice(messages, func(i, j int) bool {
			return messages[i].CreatedAt.After(messages[j].CreatedAt)
		})
	case "popular":
		sort.Slice(messages, func(i, j int) bool {
			return messages[i].LikesCount > messages[j].LikesCount
		})
	}

	// Mettre en cache les requetes par distance (le cas le plus frequent)
	if q.Hashtag == "" && (q.Sort == "" || q.Sort == "distance") {
		key := cache.NearbyKey(q.Latitude, q.Longitude, q.Radius)
		if err := s.cache.Set(ctx, key, messages); err != nil {
			log.Printf("[cache] erreur SET: %v", err)
		}
	}

	return messages, nil
}

func (s *MessageService) Delete(ctx context.Context, id, userID string) error {
	err := s.repo.Delete(ctx, id, userID)
	if err != nil {
		return err
	}

	// Invalider le cache
	s.cache.InvalidateZone(ctx)
	return nil
}

func (s *MessageService) GetByUser(ctx context.Context, userID string) ([]model.Message, error) {
	return s.repo.GetByUser(ctx, userID)
}
