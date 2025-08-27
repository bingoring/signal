package services

import (
	"signal-module/pkg/logger"
)

type WebSocketService struct {
	logger *logger.Logger
}

func NewWebSocketService(logger *logger.Logger) *WebSocketService {
	return &WebSocketService{
		logger: logger,
	}
}