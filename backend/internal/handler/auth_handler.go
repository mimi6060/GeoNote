package handler

import (
	"net/http"

	"github.com/mimi6060/GeoNote/backend/internal/middleware"
	"github.com/mimi6060/GeoNote/backend/internal/model"
	"github.com/mimi6060/GeoNote/backend/internal/service"
)

type AuthHandler struct {
	svc *service.AuthService
}

func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req model.RegisterRequest
	if err := DecodeJSON(r, &req); err != nil {
		WriteError(w, http.StatusBadRequest, "INVALID_JSON", "JSON invalide")
		return
	}

	if errs := req.Validate(); len(errs) > 0 {
		WriteValidationError(w, errs)
		return
	}

	resp, err := h.svc.Register(r.Context(), req)
	if err != nil {
		WriteError(w, http.StatusConflict, "REGISTER_FAILED", err.Error())
		return
	}

	WriteJSON(w, http.StatusCreated, resp)
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req model.LoginRequest
	if err := DecodeJSON(r, &req); err != nil {
		WriteError(w, http.StatusBadRequest, "INVALID_JSON", "JSON invalide")
		return
	}

	if errs := req.Validate(); len(errs) > 0 {
		WriteValidationError(w, errs)
		return
	}

	resp, err := h.svc.Login(r.Context(), req)
	if err != nil {
		WriteError(w, http.StatusUnauthorized, "LOGIN_FAILED", err.Error())
		return
	}

	WriteJSON(w, http.StatusOK, resp)
}

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r.Context())
	user, err := h.svc.GetUser(r.Context(), userID)
	if err != nil {
		WriteError(w, http.StatusNotFound, "USER_NOT_FOUND", "Utilisateur introuvable")
		return
	}
	WriteJSON(w, http.StatusOK, user)
}
