package middleware

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"
)

type visitor struct {
	tokens   float64
	lastSeen time.Time
}

// RateLimit uses token bucket: maxBurst capacity, refills at rate tokens/sec.
func RateLimit(rate float64, maxBurst int) func(http.Handler) http.Handler {
	var mu sync.Mutex
	visitors := make(map[string]*visitor)

	// Cleanup old entries every 30s
	go func() {
		for {
			time.Sleep(30 * time.Second)
			mu.Lock()
			for ip, v := range visitors {
				if time.Since(v.lastSeen) > time.Minute {
					delete(visitors, ip)
				}
			}
			mu.Unlock()
		}
	}()

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := r.RemoteAddr

			mu.Lock()
			v, exists := visitors[ip]
			now := time.Now()

			if !exists {
				v = &visitor{tokens: float64(maxBurst), lastSeen: now}
				visitors[ip] = v
			}

			// Refill tokens based on elapsed time
			elapsed := now.Sub(v.lastSeen).Seconds()
			v.tokens += elapsed * rate
			if v.tokens > float64(maxBurst) {
				v.tokens = float64(maxBurst)
			}
			v.lastSeen = now

			if v.tokens < 1 {
				mu.Unlock()
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"success": false,
					"error": map[string]string{
						"code":    "RATE_LIMIT",
						"message": "Trop de requetes",
					},
				})
				return
			}

			v.tokens--
			mu.Unlock()

			next.ServeHTTP(w, r)
		})
	}
}

// AntiSpam limits authenticated users to 1 action per cooldown (e.g. message creation).
func AntiSpam(cooldown time.Duration) func(http.Handler) http.Handler {
	var mu sync.Mutex
	lastAction := make(map[string]time.Time)

	go func() {
		for {
			time.Sleep(time.Minute)
			mu.Lock()
			for uid, t := range lastAction {
				if time.Since(t) > cooldown*2 {
					delete(lastAction, uid)
				}
			}
			mu.Unlock()
		}
	}()

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID := GetUserID(r.Context())
			if userID == "" {
				next.ServeHTTP(w, r)
				return
			}

			mu.Lock()
			last, exists := lastAction[userID]
			now := time.Now()
			if exists && now.Sub(last) < cooldown {
				mu.Unlock()
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"success": false,
					"error": map[string]string{
						"code":    "SPAM_LIMIT",
						"message": "Attendez avant de poster a nouveau",
					},
				})
				return
			}
			lastAction[userID] = now
			mu.Unlock()

			next.ServeHTTP(w, r)
		})
	}
}
