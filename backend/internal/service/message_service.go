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
	repo            *repository.MessageRepo
	gamRepo         *repository.GamificationRepo
	interactionRepo *repository.InteractionRepo
	cache           *cache.RedisCache
	hub             *ws.Hub
}

func NewMessageService(repo *repository.MessageRepo, gamRepo *repository.GamificationRepo, interactionRepo *repository.InteractionRepo, c *cache.RedisCache, hub *ws.Hub) *MessageService {
	return &MessageService{repo: repo, gamRepo: gamRepo, interactionRepo: interactionRepo, cache: c, hub: hub}
}

func (s *MessageService) Create(ctx context.Context, userID string, req model.CreateMessageRequest) (*model.Message, error) {
	msg, err := s.repo.Create(ctx, userID, req)
	if err != nil {
		return nil, err
	}

	s.cache.InvalidateZone(ctx)
	if msg.MessageType == "mystery" {
		masked := *msg
		masked.Content = "???"
		s.hub.BroadcastNewMessage(&masked)
	} else {
		s.hub.BroadcastNewMessage(msg)
	}

	// Update gamification: streak + badges
	if s.gamRepo != nil {
		s.gamRepo.RecordPost(ctx, userID, req.Latitude, req.Longitude)
		s.gamRepo.CheckAndAwardBadges(ctx, userID)
		if req.MessageType == "capsule" {
			s.gamRepo.AwardBadge(ctx, userID, "capsule_creator")
		}
	}

	return msg, nil
}

func (s *MessageService) GetNearby(ctx context.Context, q model.NearbyQuery) ([]model.Message, error) {
	if q.Radius <= 0 {
		q.Radius = 1000
	}
	if q.Limit <= 0 || q.Limit > 50 {
		q.Limit = 50
	}

	// Grid cache
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

	// Hide mystery message content for users who haven't unlocked them
	hasMaskedMystery := false
	for i := range messages {
		if messages[i].MessageType == "mystery" {
			if q.UserID == "" || messages[i].UserID != q.UserID {
				// Check if unlocked
				if q.UserID != "" {
					unlocked, _ := s.repo.IsUnlocked(ctx, messages[i].ID, q.UserID)
					if unlocked {
						continue
					}
				}
				messages[i].Content = "???"
				hasMaskedMystery = true
			}
		}
	}

	// Enrich messages with reactions
	if s.interactionRepo != nil && len(messages) > 0 {
		msgIDs := make([]string, len(messages))
		for i := range messages {
			msgIDs[i] = messages[i].ID
		}
		reactionsMap, err := s.interactionRepo.GetReactionsByMessages(ctx, msgIDs, q.UserID)
		if err == nil && reactionsMap != nil {
			for i := range messages {
				if r, ok := reactionsMap[messages[i].ID]; ok {
					messages[i].Reactions = r
				}
			}
		}
	}

	// Ranking
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
		now := time.Now()
		sort.Slice(messages, func(i, j int) bool {
			return rankScore(&messages[i], now) > rankScore(&messages[j], now)
		})
	}

	// Cache store — skip caching if any mystery content was masked to avoid cache poisoning
	if q.Hashtag == "" && (q.Sort == "" || q.Sort == "distance") && !hasMaskedMystery {
		key := cache.GridKey(q.Latitude, q.Longitude, q.Radius, q.UserID)
		if err := s.cache.Set(ctx, key, messages); err != nil {
			log.Printf("[cache] erreur SET: %v", err)
		}
	}

	return messages, nil
}

func rankScore(m *model.Message, now time.Time) float64 {
	dist := 1000.0
	if m.Distance != nil && *m.Distance > 0 {
		dist = *m.Distance
	}
	distScore := 1.0 - math.Min(dist, 1000.0)/1000.0
	likesScore := math.Log1p(float64(m.LikesCount)) / 5.0
	hours := now.Sub(m.CreatedAt).Hours()
	recencyScore := math.Exp(-hours / 8.66)
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

// UnlockMystery attempts to unlock a mystery message (user must be within mystery_radius).
func (s *MessageService) UnlockMystery(ctx context.Context, messageID, userID string, userLat, userLng float64) (*model.Message, bool, error) {
	// Get all nearby messages and find the target
	messages, err := s.repo.GetNearby(ctx, model.NearbyQuery{
		Latitude: userLat, Longitude: userLng, Radius: 1000, Limit: 100, UserID: userID,
	})
	if err != nil {
		return nil, false, err
	}

	var target *model.Message
	for i := range messages {
		if messages[i].ID == messageID {
			target = &messages[i]
			break
		}
	}
	if target == nil {
		return nil, false, repository.ErrNotFound
	}
	if target.MessageType != "mystery" {
		return target, false, nil
	}

	// Check distance
	if target.Distance != nil && *target.Distance > float64(target.MysteryRadius) {
		return target, false, nil
	}

	newlyUnlocked, err := s.repo.UnlockMystery(ctx, messageID, userID)
	if err != nil {
		return nil, false, err
	}

	if newlyUnlocked && s.gamRepo != nil {
		s.gamRepo.RecordUnlock(ctx, userID)
		s.gamRepo.CheckAndAwardBadges(ctx, userID)
	}

	// Return full content — re-fetch from DB since target.Content may have been masked
	realContent, err := s.repo.GetMessageContent(ctx, messageID)
	if err == nil {
		target.Content = realContent
	}
	return target, newlyUnlocked, nil
}

// GetHeatmap returns zone activity data.
func (s *MessageService) GetHeatmap(ctx context.Context, lat, lng float64, radius int) ([]model.HeatmapPoint, error) {
	if radius > 5000 {
		radius = 5000
	}
	return s.repo.GetHeatmap(ctx, lat, lng, radius)
}

// GetLeaderboard returns local rankings.
func (s *MessageService) GetLeaderboard(ctx context.Context, lat, lng float64, radius, limit int) ([]model.LeaderboardEntry, error) {
	if radius > 10000 {
		radius = 10000
	}
	if limit > 50 {
		limit = 50
	}
	return s.repo.GetLeaderboard(ctx, lat, lng, radius, limit)
}

// DetectEvents returns active event clusters nearby.
func (s *MessageService) DetectEvents(ctx context.Context, lat, lng float64, radius int) ([]model.Event, error) {
	if radius > 10000 {
		radius = 10000
	}
	return s.repo.DetectEvents(ctx, lat, lng, radius)
}
