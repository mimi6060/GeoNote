package handler

import (
	"net/http"

	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type SearchHandler struct {
	svc *service.SearchService
}

func NewSearchHandler(svc *service.SearchService) *SearchHandler {
	return &SearchHandler{svc: svc}
}

// Search handles GET /search?q=&type=hashtag|user&limit=&offset=
func (h *SearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		WriteError(w, http.StatusBadRequest, "MISSING_QUERY", "Le parametre q est requis")
		return
	}

	searchType := r.URL.Query().Get("type")
	if searchType == "" {
		searchType = "hashtag"
	}
	if searchType != "hashtag" && searchType != "user" {
		WriteError(w, http.StatusBadRequest, "INVALID_TYPE", "type doit etre hashtag ou user")
		return
	}

	limit := parseInt(r, "limit", 20)
	if limit > 50 {
		limit = 50
	}
	offset := parseInt(r, "offset", 0)

	result, err := h.svc.Search(r.Context(), model.SearchQuery{
		Query:  q,
		Type:   searchType,
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "SEARCH_ERROR", "Erreur de recherche")
		return
	}

	WriteJSON(w, http.StatusOK, result)
}

// PopularHashtags handles GET /search/hashtags/popular?limit=
func (h *SearchHandler) PopularHashtags(w http.ResponseWriter, r *http.Request) {
	limit := parseInt(r, "limit", 10)
	if limit > 50 {
		limit = 50
	}

	hashtags, err := h.svc.GetPopularHashtags(r.Context(), limit)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "HASHTAG_ERROR", "Erreur serveur")
		return
	}

	WriteJSON(w, http.StatusOK, map[string]interface{}{
		"hashtags": hashtags,
		"count":    len(hashtags),
	})
}
