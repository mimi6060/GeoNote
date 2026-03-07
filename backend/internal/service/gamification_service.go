package service

import (
	"context"

	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
)

type GamificationService struct {
	repo *repository.GamificationRepo
}

func NewGamificationService(repo *repository.GamificationRepo) *GamificationService {
	return &GamificationService{repo: repo}
}

func (s *GamificationService) GetStreak(ctx context.Context, userID string) (*model.UserStreak, error) {
	return s.repo.GetStreak(ctx, userID)
}

func (s *GamificationService) GetBadges(ctx context.Context, userID string) ([]model.Badge, error) {
	return s.repo.GetBadges(ctx, userID)
}

func (s *GamificationService) GetProfile(ctx context.Context, userID string) (map[string]interface{}, error) {
	streak, err := s.repo.GetStreak(ctx, userID)
	if err != nil {
		return nil, err
	}
	badges, err := s.repo.GetBadges(ctx, userID)
	if err != nil {
		return nil, err
	}
	if badges == nil {
		badges = []model.Badge{}
	}
	return map[string]interface{}{
		"streak": streak,
		"badges": badges,
	}, nil
}
