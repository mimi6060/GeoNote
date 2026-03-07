package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/mimi6060/GeoNote/backend/internal/middleware"
	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type MessageHandler struct {
	svc *service.MessageService
}

func NewMessageHandler(svc *service.MessageService) *MessageHandler {
	return &MessageHandler{svc: svc}
}

func (h *MessageHandler) GetNearby(w http.ResponseWriter, r *http.Request) {
	radius := parseInt(r, "radius", 1000)
	if radius > 1000 {
		radius = 1000
	}
	limit := parseInt(r, "limit", 50)
	if limit > 50 {
		limit = 50
	}

	q := model.NearbyQuery{
		Latitude:  parseFloat(r, "lat", 48.8566),
		Longitude: parseFloat(r, "lng", 2.3522),
		Radius:    radius,
		Limit:     limit,
		Sort:      r.URL.Query().Get("sort"),
		Hashtag:   r.URL.Query().Get("hashtag"),
		UserID:    middleware.GetUserID(r.Context()),
	}

	messages, err := h.svc.GetNearby(r.Context(), q)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "FETCH_ERROR", "Erreur serveur")
		return
	}

	if messages == nil {
		messages = []model.Message{}
	}

	WriteJSON(w, http.StatusOK, map[string]interface{}{
		"messages": messages,
		"count":    len(messages),
		"center":   map[string]float64{"lat": q.Latitude, "lng": q.Longitude},
		"radius":   q.Radius,
	})
}

func (h *MessageHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())

	var req model.CreateMessageRequest
	if err := DecodeJSON(r, &req); err != nil {
		WriteError(w, http.StatusBadRequest, "INVALID_JSON", "JSON invalide")
		return
	}

	if errs := req.Validate(); len(errs) > 0 {
		WriteValidationError(w, errs)
		return
	}

	msg, err := h.svc.Create(r.Context(), userID, req)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "CREATE_ERROR", "Erreur lors de la creation")
		return
	}

	WriteJSON(w, http.StatusCreated, msg)
}

func (h *MessageHandler) Delete(w http.ResponseWriter, r *http.Request) {
	messageID := chi.URLParam(r, "id")
	userID := middleware.GetUserID(r.Context())

	err := h.svc.Delete(r.Context(), messageID, userID)
	if errors.Is(err, repository.ErrNotFound) {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Message introuvable ou non autorise")
		return
	}
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "DELETE_ERROR", "Erreur serveur")
		return
	}

	WriteJSON(w, http.StatusOK, map[string]string{"message": "Message supprime"})
}

func (h *MessageHandler) GetByUser(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "id")

	messages, err := h.svc.GetByUser(r.Context(), userID)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "FETCH_ERROR", "Erreur serveur")
		return
	}

	if messages == nil {
		messages = []model.Message{}
	}

	WriteJSON(w, http.StatusOK, map[string]interface{}{
		"messages": messages,
		"count":    len(messages),
	})
}

func parseFloat(r *http.Request, key string, fallback float64) float64 {
	v, err := strconv.ParseFloat(r.URL.Query().Get(key), 64)
	if err != nil {
		return fallback
	}
	return v
}

func parseInt(r *http.Request, key string, fallback int) int {
	v, err := strconv.Atoi(r.URL.Query().Get(key))
	if err != nil || v <= 0 {
		return fallback
	}
	return v
}
