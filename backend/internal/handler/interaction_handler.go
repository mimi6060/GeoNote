package handler

import (
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mimi6060/GeoNote/backend/internal/middleware"
	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/repository"
	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type InteractionHandler struct {
	svc *service.InteractionService
}

func NewInteractionHandler(svc *service.InteractionService) *InteractionHandler {
	return &InteractionHandler{svc: svc}
}

func (h *InteractionHandler) ToggleLike(w http.ResponseWriter, r *http.Request) {
	messageID := chi.URLParam(r, "id")
	userID := middleware.GetUserID(r.Context())

	resp, err := h.svc.ToggleLike(r.Context(), messageID, userID)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "LIKE_ERROR", "Erreur serveur")
		return
	}

	WriteJSON(w, http.StatusOK, resp)
}

func (h *InteractionHandler) GetComments(w http.ResponseWriter, r *http.Request) {
	messageID := chi.URLParam(r, "id")

	comments, err := h.svc.GetComments(r.Context(), messageID)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "FETCH_ERROR", "Erreur serveur")
		return
	}

	if comments == nil {
		comments = []model.Interaction{}
	}

	WriteJSON(w, http.StatusOK, map[string]interface{}{
		"comments": comments,
		"count":    len(comments),
	})
}

func (h *InteractionHandler) AddComment(w http.ResponseWriter, r *http.Request) {
	messageID := chi.URLParam(r, "id")
	userID := middleware.GetUserID(r.Context())

	var req model.CreateCommentRequest
	if err := DecodeJSON(r, &req); err != nil {
		WriteError(w, http.StatusBadRequest, "INVALID_JSON", "JSON invalide")
		return
	}

	if errs := req.Validate(); len(errs) > 0 {
		WriteValidationError(w, errs)
		return
	}

	comment, err := h.svc.AddComment(r.Context(), messageID, userID, req.Content)
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "COMMENT_ERROR", "Erreur serveur")
		return
	}

	WriteJSON(w, http.StatusCreated, comment)
}

func (h *InteractionHandler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	commentID := chi.URLParam(r, "commentId")
	userID := middleware.GetUserID(r.Context())

	err := h.svc.DeleteComment(r.Context(), commentID, userID)
	if errors.Is(err, repository.ErrNotFound) {
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "Commentaire introuvable ou non autorise")
		return
	}
	if err != nil {
		WriteError(w, http.StatusInternalServerError, "DELETE_ERROR", "Erreur serveur")
		return
	}

	WriteJSON(w, http.StatusOK, map[string]string{"message": "Commentaire supprime"})
}
