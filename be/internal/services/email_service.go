package services

import (
	"fmt"
	"net/smtp"
)

type EmailService struct {
	smtpHost     string
	smtpPort     string
	smtpUsername string
	smtpPassword string
	fromEmail    string
	fromName     string
}

type EmailTemplate struct {
	Subject string
	Body    string
}

func NewEmailService(smtpHost, smtpPort, smtpUsername, smtpPassword, fromEmail, fromName string) *EmailService {
	return &EmailService{
		smtpHost:     smtpHost,
		smtpPort:     smtpPort,
		smtpUsername: smtpUsername,
		smtpPassword: smtpPassword,
		fromEmail:    fromEmail,
		fromName:     fromName,
	}
}

// SendMagicLinkEmail sends a magic link email to the user
func (es *EmailService) SendMagicLinkEmail(to, magicLink, purpose string) error {
	var template EmailTemplate
	
	if purpose == "signup" {
		template = es.getSignupTemplate(magicLink)
	} else {
		template = es.getLoginTemplate(magicLink)
	}
	
	return es.sendEmail(to, template.Subject, template.Body)
}

// sendEmail sends an email using SMTP
func (es *EmailService) sendEmail(to, subject, body string) error {
	// Create authentication
	auth := smtp.PlainAuth("", es.smtpUsername, es.smtpPassword, es.smtpHost)
	
	// Compose message
	msg := es.composeMessage(to, subject, body)
	
	// Send email
	addr := fmt.Sprintf("%s:%s", es.smtpHost, es.smtpPort)
	err := smtp.SendMail(addr, auth, es.fromEmail, []string{to}, []byte(msg))
	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}
	
	return nil
}

// composeMessage creates the email message with headers
func (es *EmailService) composeMessage(to, subject, body string) string {
	return fmt.Sprintf(
		"From: %s <%s>\r\n"+
			"To: %s\r\n"+
			"Subject: %s\r\n"+
			"MIME-Version: 1.0\r\n"+
			"Content-Type: text/html; charset=UTF-8\r\n"+
			"\r\n"+
			"%s",
		es.fromName, es.fromEmail, to, subject, body)
}

// getLoginTemplate returns the login email template
func (es *EmailService) getLoginTemplate(magicLink string) EmailTemplate {
	subject := "Signal 로그인 링크"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Signal 로그인</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; }
        .header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 40px 30px; text-align: center; }
        .content { padding: 40px 30px; }
        .button { display: inline-block; padding: 15px 30px; background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 20px 0; }
        .footer { background-color: #f8f9fa; padding: 20px 30px; text-align: center; color: #666; font-size: 14px; }
        .warning { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Signal</h1>
            <p>로그인 링크가 도착했습니다!</p>
        </div>
        <div class="content">
            <h2>안녕하세요!</h2>
            <p>Signal 앱에 로그인하시려면 아래 버튼을 클릭해주세요.</p>
            
            <p style="text-align: center;">
                <a href="%s" class="button">Signal에 로그인하기</a>
            </p>
            
            <div class="warning">
                <p><strong>⚠️ 보안 안내</strong></p>
                <ul>
                    <li>이 링크는 15분 후에 만료됩니다</li>
                    <li>링크는 한 번만 사용할 수 있습니다</li>
                    <li>본인이 요청하지 않았다면 이 이메일을 무시하세요</li>
                </ul>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                버튼이 작동하지 않으면 아래 링크를 복사해서 브라우저에 붙여넣으세요:<br>
                <span style="word-break: break-all;">%s</span>
            </p>
        </div>
        <div class="footer">
            <p>이 이메일은 Signal 앱에서 자동으로 발송되었습니다.</p>
            <p>문의사항이 있으시면 고객센터로 연락해주세요.</p>
        </div>
    </div>
</body>
</html>`, magicLink, magicLink)
	
	return EmailTemplate{
		Subject: subject,
		Body:    body,
	}
}

// getSignupTemplate returns the signup email template
func (es *EmailService) getSignupTemplate(magicLink string) EmailTemplate {
	subject := "Signal 회원가입을 완료해주세요"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Signal 회원가입</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; }
        .header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 40px 30px; text-align: center; }
        .content { padding: 40px 30px; }
        .button { display: inline-block; padding: 15px 30px; background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 20px 0; }
        .footer { background-color: #f8f9fa; padding: 20px 30px; text-align: center; color: #666; font-size: 14px; }
        .welcome { background: linear-gradient(135deg, #e3f2fd 0%%, #f3e5f5 100%%); padding: 20px; border-radius: 8px; margin: 20px 0; }
        .warning { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎉 Signal에 오신 것을 환영합니다!</h1>
            <p>회원가입을 완료하고 새로운 만남을 시작하세요</p>
        </div>
        <div class="content">
            <div class="welcome">
                <h2>🚀 Signal에서 할 수 있는 일들</h2>
                <ul>
                    <li>📍 내 주변의 실시간 시그널 탐색</li>
                    <li>💬 관심 있는 활동에 참여하고 채팅</li>
                    <li>👥 새로운 사람들과 만남</li>
                    <li>🎯 나만의 시그널 생성</li>
                </ul>
            </div>
            
            <p>회원가입을 완료하려면 아래 버튼을 클릭해주세요.</p>
            
            <p style="text-align: center;">
                <a href="%s" class="button">회원가입 완료하기</a>
            </p>
            
            <div class="warning">
                <p><strong>⚠️ 보안 안내</strong></p>
                <ul>
                    <li>이 링크는 15분 후에 만료됩니다</li>
                    <li>링크는 한 번만 사용할 수 있습니다</li>
                    <li>본인이 요청하지 않았다면 이 이메일을 무시하세요</li>
                </ul>
            </div>
            
            <p style="color: #666; font-size: 14px;">
                버튼이 작동하지 않으면 아래 링크를 복사해서 브라우저에 붙여넣으세요:<br>
                <span style="word-break: break-all;">%s</span>
            </p>
        </div>
        <div class="footer">
            <p>이 이메일은 Signal 앱에서 자동으로 발송되었습니다.</p>
            <p>문의사항이 있으시면 고객센터로 연락해주세요.</p>
        </div>
    </div>
</body>
</html>`, magicLink, magicLink)
	
	return EmailTemplate{
		Subject: subject,
		Body:    body,
	}
}

// TestConnection tests the email service connection
func (es *EmailService) TestConnection() error {
	auth := smtp.PlainAuth("", es.smtpUsername, es.smtpPassword, es.smtpHost)
	addr := fmt.Sprintf("%s:%s", es.smtpHost, es.smtpPort)
	
	client, err := smtp.Dial(addr)
	if err != nil {
		return fmt.Errorf("failed to connect to SMTP server: %w", err)
	}
	defer client.Close()
	
	err = client.Auth(auth)
	if err != nil {
		return fmt.Errorf("failed to authenticate with SMTP server: %w", err)
	}
	
	return nil
}