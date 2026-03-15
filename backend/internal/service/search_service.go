package service

import (
	"context"

	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
)

type SearchService struct {
	messageRepo *repository.MessageRepo
	userRepo    *repository.UserRepo
}

func NewSearchService(messageRepo *repository.MessageRepo, userRepo *repository.UserRepo) *SearchService {
	return &SearchService{messageRepo: messageRepo, userRepo: userRepo}
}

// Search dispatches to the appropriate search depending on type.
func (s *SearchService) Search(ctx context.Context, q model.SearchQuery) (*model.SearchResult, error) {
	if q.Limit <= 0 || q.Limit > 50 {
		q.Limit = 20
	}
	if q.Offset < 0 {
		q.Offset = 0
	}

	switch q.Type {
	case "user":
		return s.searchUsers(ctx, q)
	default:
		return s.searchHashtags(ctx, q)
	}
}

func (s *SearchService) searchHashtags(ctx context.Context, q model.SearchQuery) (*model.SearchResult, error) {
	messages, total, err := s.messageRepo.SearchByHashtag(ctx, q.Query, q.Limit, q.Offset)
	if err != nil {
		return nil, err
	}

	// Mask mystery message content
	for i := range messages {
		if messages[i].MessageType == "mystery" {
			messages[i].Content = "???"
		}
	}

	if messages == nil {
		messages = []model.Message{}
	}

	return &model.SearchResult{
		Messages: messages,
		Total:    total,
	}, nil
}

func (s *SearchService) searchUsers(ctx context.Context, q model.SearchQuery) (*model.SearchResult, error) {
	users, total, err := s.userRepo.SearchByUsername(ctx, q.Query, q.Limit, q.Offset)
	if err != nil {
		return nil, err
	}

	if users == nil {
		users = []model.UserSummary{}
	}

	return &model.SearchResult{
		Users: users,
		Total: total,
	}, nil
}

// GetPopularHashtags returns the most popular hashtags.
func (s *SearchService) GetPopularHashtags(ctx context.Context, limit int) ([]model.HashtagResult, error) {
	if limit <= 0 || limit > 50 {
		limit = 10
	}
	hashtags, err := s.messageRepo.GetPopularHashtags(ctx, limit)
	if err != nil {
		return nil, err
	}
	if hashtags == nil {
		hashtags = []model.HashtagResult{}
	}
	return hashtags, nil
}
