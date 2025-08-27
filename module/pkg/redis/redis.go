package redis

import (
	"context"
	"fmt"
	"log"
	"time"

	"signal-module/pkg/config"

	"github.com/redis/go-redis/v9"
)

type Client struct {
	rdb *redis.Client
}

func New(cfg *config.RedisConfig) (*Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.Host, cfg.Port),
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("Redis 연결 실패: %w", err)
	}

	log.Println("✅ Redis 연결 완료")
	return &Client{rdb: rdb}, nil
}

func (c *Client) GetClient() *redis.Client {
	return c.rdb
}

// 캐시 관련 메서드들
func (c *Client) Set(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
	return c.rdb.Set(ctx, key, value, expiration).Err()
}

func (c *Client) Get(ctx context.Context, key string) (string, error) {
	return c.rdb.Get(ctx, key).Result()
}

func (c *Client) Delete(ctx context.Context, keys ...string) error {
	return c.rdb.Del(ctx, keys...).Err()
}

func (c *Client) Exists(ctx context.Context, keys ...string) (int64, error) {
	return c.rdb.Exists(ctx, keys...).Result()
}

// 지리적 위치 관련 메서드들 (GEO 명령어)
func (c *Client) GeoAdd(ctx context.Context, key string, locations ...*redis.GeoLocation) error {
	return c.rdb.GeoAdd(ctx, key, locations...).Err()
}

func (c *Client) GeoRadius(ctx context.Context, key string, longitude, latitude, radius float64) ([]redis.GeoLocation, error) {
	return c.rdb.GeoRadius(ctx, key, longitude, latitude, &redis.GeoRadiusQuery{
		Radius: radius,
		Unit:   "m",
		WithGeoHash: true,
		WithCoord:   true,
		WithDist:    true,
		Count:       100,
		Sort:        "ASC",
	}).Result()
}

func (c *Client) GeoRemove(ctx context.Context, key string, members ...interface{}) error {
	return c.rdb.ZRem(ctx, key, members...).Err()
}

// Set 관련 메서드들 (사용자 온라인 상태 등)
func (c *Client) SAdd(ctx context.Context, key string, members ...interface{}) error {
	return c.rdb.SAdd(ctx, key, members...).Err()
}

func (c *Client) SRem(ctx context.Context, key string, members ...interface{}) error {
	return c.rdb.SRem(ctx, key, members...).Err()
}

func (c *Client) SMembers(ctx context.Context, key string) ([]string, error) {
	return c.rdb.SMembers(ctx, key).Result()
}

func (c *Client) SIsMember(ctx context.Context, key string, member interface{}) (bool, error) {
	return c.rdb.SIsMember(ctx, key, member).Result()
}

// Hash 관련 메서드들
func (c *Client) HSet(ctx context.Context, key string, values ...interface{}) error {
	return c.rdb.HSet(ctx, key, values...).Err()
}

func (c *Client) HGet(ctx context.Context, key, field string) (string, error) {
	return c.rdb.HGet(ctx, key, field).Result()
}

func (c *Client) HGetAll(ctx context.Context, key string) (map[string]string, error) {
	return c.rdb.HGetAll(ctx, key).Result()
}

func (c *Client) HDel(ctx context.Context, key string, fields ...string) error {
	return c.rdb.HDel(ctx, key, fields...).Err()
}

// List 관련 메서드들 (작업 큐 등)
func (c *Client) LPush(ctx context.Context, key string, values ...interface{}) error {
	return c.rdb.LPush(ctx, key, values...).Err()
}

func (c *Client) RPop(ctx context.Context, key string) (string, error) {
	return c.rdb.RPop(ctx, key).Result()
}

func (c *Client) BRPop(ctx context.Context, timeout time.Duration, keys ...string) ([]string, error) {
	return c.rdb.BRPop(ctx, timeout, keys...).Result()
}

func (c *Client) LLen(ctx context.Context, key string) (int64, error) {
	return c.rdb.LLen(ctx, key).Result()
}

// Pub/Sub 관련 메서드들
func (c *Client) Publish(ctx context.Context, channel string, message interface{}) error {
	return c.rdb.Publish(ctx, channel, message).Err()
}

func (c *Client) Subscribe(ctx context.Context, channels ...string) *redis.PubSub {
	return c.rdb.Subscribe(ctx, channels...)
}

// 만료 시간 관련
func (c *Client) Expire(ctx context.Context, key string, expiration time.Duration) error {
	return c.rdb.Expire(ctx, key, expiration).Err()
}

func (c *Client) TTL(ctx context.Context, key string) (time.Duration, error) {
	return c.rdb.TTL(ctx, key).Result()
}

// Signal 특화 메서드들
func (c *Client) AddActiveSignal(ctx context.Context, signalID uint, latitude, longitude float64) error {
	return c.GeoAdd(ctx, "active_signals", &redis.GeoLocation{
		Name:      fmt.Sprintf("signal:%d", signalID),
		Longitude: longitude,
		Latitude:  latitude,
	})
}

func (c *Client) RemoveActiveSignal(ctx context.Context, signalID uint) error {
	return c.GeoRemove(ctx, "active_signals", fmt.Sprintf("signal:%d", signalID))
}

func (c *Client) FindNearbySignals(ctx context.Context, longitude, latitude, radius float64) ([]redis.GeoLocation, error) {
	return c.GeoRadius(ctx, "active_signals", longitude, latitude, radius)
}

// 사용자 온라인 상태 관리
func (c *Client) SetUserOnline(ctx context.Context, userID uint) error {
	return c.SAdd(ctx, "online_users", userID)
}

func (c *Client) SetUserOffline(ctx context.Context, userID uint) error {
	return c.SRem(ctx, "online_users", userID)
}

func (c *Client) IsUserOnline(ctx context.Context, userID uint) (bool, error) {
	return c.SIsMember(ctx, "online_users", userID)
}

func (c *Client) Close() error {
	return c.rdb.Close()
}