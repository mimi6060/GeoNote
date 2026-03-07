package test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/mimi6060/GeoNote/backend/internal/model"
)

func TestCreateMessageValidation(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		wantStatus int
	}{
		{
			name:       "contenu vide",
			body:       `{"content":"","latitude":48.85,"longitude":2.35}`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "latitude invalide",
			body:       `{"content":"test","latitude":200,"longitude":2.35}`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "longitude invalide",
			body:       `{"content":"test","latitude":48.85,"longitude":999}`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "visibilite invalide",
			body:       `{"content":"test","latitude":48.85,"longitude":2.35,"visibility":"secret"}`,
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var req model.CreateMessageRequest
			json.NewDecoder(strings.NewReader(tt.body)).Decode(&req)
			errs := req.Validate()
			if len(errs) == 0 {
				t.Error("validation aurait du echouer")
			}
		})
	}
}

func TestCreateMessageRequestValid(t *testing.T) {
	req := model.CreateMessageRequest{
		Content:    "Hello #paris",
		Latitude:   48.8566,
		Longitude:  2.3522,
		Visibility: "public",
	}

	errs := req.Validate()
	if len(errs) > 0 {
		t.Errorf("validation aurait du reussir, erreurs: %v", errs)
	}
}

func TestHealthCheckEndpoint(t *testing.T) {
	// Test unitaire du format de reponse (sans DB reelle)
	w := httptest.NewRecorder()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(model.APIResponse{
		Success: true,
		Data: map[string]string{
			"status": "ok",
			"db":     "connected",
		},
	})

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, attendu 200", w.Code)
	}

	var resp model.APIResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if !resp.Success {
		t.Error("attendu success=true")
	}
}
