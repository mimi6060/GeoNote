package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisCache struct {
	client *redis.Client
	ttl    time.Duration
}

func NewRedisCache(addr, password string, db int, ttl time.Duration) *RedisCache {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		log.Printf("[cache] Redis indisponible (%s), cache desactive: %v", addr, err)
		return &RedisCache{client: nil, ttl: ttl}
	}

	log.Printf("[cache] connecte a Redis %s", addr)
	return &RedisCache{client: client, ttl: ttl}
}

// NearbyKey genere une cle de cache pour une zone geographique.
// On arrondit lat/lng a 3 decimales (~111m de precision) pour regrouper les requetes proches.
func NearbyKey(lat, lng float64, radius int) string {
	return fmt.Sprintf("nearby:%.3f:%.3f:%d", lat, lng, radius)
}

// Get recupere une valeur du cache et la deserialise.
func (c *RedisCache) Get(ctx context.Context, key string, dest interface{}) error {
	if c.client == nil {
		return fmt.Errorf("cache desactive")
	}

	val, err := c.client.Get(ctx, key).Result()
	if err != nil {
		return err
	}

	return json.Unmarshal([]byte(val), dest)
}

// Set serialise et stocke une valeur dans le cache.
func (c *RedisCache) Set(ctx context.Context, key string, value interface{}) error {
	if c.client == nil {
		return nil
	}

	data, err := json.Marshal(value)
	if err != nil {
		return err
	}

	return c.client.Set(ctx, key, data, c.ttl).Err()
}

// InvalidateZone supprime toutes les cles de cache "nearby:*".
// Appele apres creation/suppression d'un message.
func (c *RedisCache) InvalidateZone(ctx context.Context) {
	if c.client == nil {
		return
	}

	iter := c.client.Scan(ctx, 0, "nearby:*", 100).Iterator()
	var keys []string
	for iter.Next(ctx) {
		keys = append(keys, iter.Val())
	}
	if len(keys) > 0 {
		c.client.Del(ctx, keys...)
	}
}

// Close ferme la connexion Redis.
func (c *RedisCache) Close() error {
	if c.client == nil {
		return nil
	}
	return c.client.Close()
}
