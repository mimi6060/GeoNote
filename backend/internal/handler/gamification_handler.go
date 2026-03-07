package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mimi6060/GeoNote/backend/internal/middleware"
	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type GamificationHandler struct {
	svc *service.GamificationService
}

func NewGamificationHandler(svc *service.GamificationService) *GamificationHandler {
	return &GamificationHandler{svc: svc}
}

// GetMyProfile returns the authenticated user's streak + badges.
func (h *GamificationHandler) GetMyProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	data, err := h.svc.GetProfile(r.Context(), userID)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "PROFILE_ERROR", "Erreur serveur")
		return
	}
	WriteJSON(w, http.StatusOK, data)
}

// GetUserProfile returns a user's public streak + badges.
func (h *GamificationHandler) GetUserProfile(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "id")
	data, err := h.svc.GetProfile(r.Context(), userID)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "PROFILE_ERROR", "Erreur serveur")
		return
	}
	WriteJSON(w, http.StatusOK, data)
}
