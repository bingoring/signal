package services

import (
	"context"
	"fmt"

	"signal-module/pkg/logger"
	"signal-module/pkg/queue"
)

type EmailService struct {
	logger *logger.Logger
}

func NewEmailService(logger *logger.Logger) *EmailService {
	return &EmailService{
		logger: logger,
	}
}

func (s *EmailService) ProcessEmailJob(ctx context.Context, job *queue.Job) error {
	to, ok := job.Payload["to"].(string)
	if !ok {
		return fmt.Errorf("잘못된 to 형식")
	}

	subject, ok := job.Payload["subject"].(string)
	if !ok {
		return fmt.Errorf("잘못된 subject 형식")
	}

	template, ok := job.Payload["template"].(string)
	if !ok {
		return fmt.Errorf("잘못된 template 형식")
	}

	data, _ := job.Payload["data"].(map[string]string)

	s.logger.Info(fmt.Sprintf("이메일 발송 시작: %s, 제목: %s", to, subject))

	// TODO: 실제 이메일 발송 로직 구현
	// 1. 템플릿 엔진을 사용하여 HTML 이메일 생성
	// 2. SMTP 또는 이메일 서비스(SendGrid, SES 등)를 통해 발송

	if err := s.sendEmail(to, subject, template, data); err != nil {
		return fmt.Errorf("이메일 발송 실패: %w", err)
	}

	s.logger.Info(fmt.Sprintf("이메일 발송 완료: %s", to))
	return nil
}

func (s *EmailService) sendEmail(to, subject, template string, data map[string]string) error {
	// TODO: 실제 이메일 발송 구현
	// 예: SendGrid, AWS SES, 또는 SMTP 서버 사용
	return nil
}