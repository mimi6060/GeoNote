package service

import (
	"context"
	"strings"

	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
)

type InteractionService struct {
	repo *repository.InteractionRepo
}

func NewInteractionService(repo *repository.InteractionRepo) *InteractionService {
	return &InteractionService{repo: repo}
}

func (s *InteractionService) ToggleLike(ctx context.Context, messageID, userID string) (*model.LikeResponse, error) {
	return s.repo.ToggleLike(ctx, messageID, userID)
}

func (s *InteractionService) AddComment(ctx context.Context, messageID, userID, content string) (*model.Interaction, error) {
	return s.repo.AddComment(ctx, messageID, userID, strings.TrimSpace(content))
}

func (s *InteractionService) DeleteComment(ctx context.Context, commentID, userID string) error {
	return s.repo.DeleteComment(ctx, commentID, userID)
}

func (s *InteractionService) GetComments(ctx context.Context, messageID string) ([]model.Interaction, error) {
	return s.repo.GetComments(ctx, messageID)
}
