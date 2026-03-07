package handler

import (
	"encoding/json"
	"net/http"

	"github.com/mimi6060/GeoNote/backend/internal/model"
)

func WriteJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(model.APIResponse{
		Success: true,
		Data:    data,
	})
}

func WriteError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(model.APIResponse{
		Success: false,
		Error: &model.APIError{
			Code:    code,
			Message: message,
		},
	})
}

func WriteValidationError(w http.ResponseWriter, fields map[string]string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	json.NewEncoder(w).Encode(model.APIResponse{
		Success: false,
		Error: &model.APIError{
			Code:    "VALIDATION_ERROR",
			Message: "Donnees invalides",
			Fields:  fields,
		},
	})
}

func DecodeJSON(r *http.Request, v interface{}) error {
	defer r.Body.Close()
	return json.NewDecoder(r.Body).Decode(v)
}
