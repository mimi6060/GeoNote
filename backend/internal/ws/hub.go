package ws

import (
	"encoding/json"
	"log"
	"sync"
)

// Event represente un evenement temps reel envoye aux clients.
type Event struct {
	Type    string      `json:"type"` // "new_message", "new_like", "new_comment"
	Payload interface{} `json:"payload"`
}

// Hub gere les connexions WebSocket et diffuse les evenements.
type Hub struct {
	mu      sync.RWMutex
	clients map[*Client]bool
}

func NewHub() *Hub {
	return &Hub{
		clients: make(map[*Client]bool),
	}
}

func (h *Hub) Register(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[client] = true
	log.Printf("[ws] client connecte (%d total)", len(h.clients))
}

func (h *Hub) Unregister(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, ok := h.clients[client]; ok {
		delete(h.clients, client)
		close(client.send)
		log.Printf("[ws] client deconnecte (%d restants)", len(h.clients))
	}
}

// Broadcast envoie un evenement a tous les clients connectes.
func (h *Hub) Broadcast(event Event) {
	data, err := json.Marshal(event)
	if err != nil {
		log.Printf("[ws] erreur serialisation: %v", err)
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for client := range h.clients {
		select {
		case client.send <- data:
		default:
			// Buffer plein, on deconnecte le client lent
			go h.Unregister(client)
		}
	}
}

// BroadcastNewMessage notifie tous les clients d'un nouveau message.
func (h *Hub) BroadcastNewMessage(payload interface{}) {
	h.Broadcast(Event{Type: "new_message", Payload: payload})
}

// BroadcastNewLike notifie tous les clients d'un nouveau like.
func (h *Hub) BroadcastNewLike(payload interface{}) {
	h.Broadcast(Event{Type: "new_like", Payload: payload})
}

// BroadcastNewComment notifie tous les clients d'un nouveau commentaire.
func (h *Hub) BroadcastNewComment(payload interface{}) {
	h.Broadcast(Event{Type: "new_comment", Payload: payload})
}
