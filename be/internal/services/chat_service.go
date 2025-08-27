package services

import (
	"signal-be/internal/repositories"
	"signal-module/pkg/logger"
	"signal-module/pkg/redis"
)

type ChatService struct {
	chatRepo    repositories.ChatRepositoryInterface
	signalRepo  repositories.SignalRepositoryInterface
	redisClient *redis.Client
	logger      *logger.Logger
}

func NewChatService(
	chatRepo repositories.ChatRepositoryInterface,
	signalRepo repositories.SignalRepositoryInterface,
	redisClient *redis.Client,
	logger *logger.Logger,
) *ChatService {
	return &ChatService{
		chatRepo:    chatRepo,
		signalRepo:  signalRepo,
		redisClient: redisClient,
		logger:      logger,
	}
}