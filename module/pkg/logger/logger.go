package logger

import (
	"context"
	"encoding/json"
	"log"
	"time"
)

type LogLevel string

const (
	DEBUG LogLevel = "DEBUG"
	INFO  LogLevel = "INFO"
	WARN  LogLevel = "WARN"
	ERROR LogLevel = "ERROR"
)

type LogEntry struct {
	Level     LogLevel               `json:"level"`
	Message   string                 `json:"message"`
	Timestamp time.Time              `json:"timestamp"`
	Service   string                 `json:"service"`
	UserID    *uint                  `json:"user_id,omitempty"`
	SignalID  *uint                  `json:"signal_id,omitempty"`
	Extra     map[string]interface{} `json:"extra,omitempty"`
}

type Logger struct {
	serviceName string
}

func New(serviceName string) *Logger {
	return &Logger{
		serviceName: serviceName,
	}
}

func (l *Logger) log(level LogLevel, message string, userID, signalID *uint, extra map[string]interface{}) {
	entry := LogEntry{
		Level:     level,
		Message:   message,
		Timestamp: time.Now().UTC(),
		Service:   l.serviceName,
		UserID:    userID,
		SignalID:  signalID,
		Extra:     extra,
	}

	if data, err := json.Marshal(entry); err == nil {
		log.Println(string(data))
	} else {
		log.Printf("[%s] %s - %s", level, l.serviceName, message)
	}
}

func (l *Logger) Debug(message string) {
	l.log(DEBUG, message, nil, nil, nil)
}

func (l *Logger) DebugWithContext(ctx context.Context, message string, extra map[string]interface{}) {
	userID := l.getUserIDFromContext(ctx)
	l.log(DEBUG, message, userID, nil, extra)
}

func (l *Logger) Info(message string) {
	l.log(INFO, message, nil, nil, nil)
}

func (l *Logger) InfoWithContext(ctx context.Context, message string, extra map[string]interface{}) {
	userID := l.getUserIDFromContext(ctx)
	l.log(INFO, message, userID, nil, extra)
}

func (l *Logger) Warn(message string) {
	l.log(WARN, message, nil, nil, nil)
}

func (l *Logger) WarnWithContext(ctx context.Context, message string, extra map[string]interface{}) {
	userID := l.getUserIDFromContext(ctx)
	l.log(WARN, message, userID, nil, extra)
}

func (l *Logger) Error(message string, err error) {
	extra := make(map[string]interface{})
	if err != nil {
		extra["error"] = err.Error()
	}
	l.log(ERROR, message, nil, nil, extra)
}

func (l *Logger) ErrorWithContext(ctx context.Context, message string, err error, extra map[string]interface{}) {
	if extra == nil {
		extra = make(map[string]interface{})
	}
	if err != nil {
		extra["error"] = err.Error()
	}
	userID := l.getUserIDFromContext(ctx)
	l.log(ERROR, message, userID, nil, extra)
}

// Signal 관련 로그
func (l *Logger) LogSignalCreated(ctx context.Context, signalID uint, creatorID uint) {
	extra := map[string]interface{}{
		"action":     "signal_created",
		"creator_id": creatorID,
	}
	l.log(INFO, "새로운 시그널이 생성되었습니다", &creatorID, &signalID, extra)
}

func (l *Logger) LogSignalJoined(ctx context.Context, signalID uint, userID uint) {
	extra := map[string]interface{}{
		"action": "signal_joined",
	}
	l.log(INFO, "시그널에 참여했습니다", &userID, &signalID, extra)
}

func (l *Logger) LogSignalExpired(ctx context.Context, signalID uint) {
	extra := map[string]interface{}{
		"action": "signal_expired",
	}
	l.log(INFO, "시그널이 만료되었습니다", nil, &signalID, extra)
}

func (l *Logger) LogChatRoomCreated(ctx context.Context, chatRoomID uint, signalID uint) {
	extra := map[string]interface{}{
		"action":       "chat_room_created",
		"chat_room_id": chatRoomID,
	}
	l.log(INFO, "채팅방이 생성되었습니다", nil, &signalID, extra)
}

func (l *Logger) LogChatRoomExpired(ctx context.Context, chatRoomID uint) {
	extra := map[string]interface{}{
		"action":       "chat_room_expired",
		"chat_room_id": chatRoomID,
	}
	l.log(INFO, "채팅방이 만료되었습니다", nil, nil, extra)
}

func (l *Logger) LogPushNotificationSent(ctx context.Context, userIDs []uint, title string) {
	extra := map[string]interface{}{
		"action":    "push_notification_sent",
		"user_ids":  userIDs,
		"title":     title,
		"user_count": len(userIDs),
	}
	l.log(INFO, "푸시 알림을 발송했습니다", nil, nil, extra)
}

// 컨텍스트에서 사용자 ID 추출 (미들웨어에서 설정됨)
func (l *Logger) getUserIDFromContext(ctx context.Context) *uint {
	if userID, exists := ctx.Value("user_id").(uint); exists {
		return &userID
	}
	return nil
}