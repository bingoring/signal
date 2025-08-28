package oauth

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	"signal-module/pkg/config"
)

// GoogleProvider Google OAuth 제공업체
type GoogleProvider struct {
	config config.GoogleConfig
}

// NewGoogleProvider Google 제공업체 생성
func NewGoogleProvider(config config.GoogleConfig) *GoogleProvider {
	return &GoogleProvider{
		config: config,
	}
}

// GetProviderName 제공업체 이름 반환
func (p *GoogleProvider) GetProviderName() string {
	return "google"
}

// ValidateConfig 설정 유효성 검사
func (p *GoogleProvider) ValidateConfig() error {
	if p.config.ClientID == "" {
		return fmt.Errorf("Google ClientID is required")
	}
	if p.config.ClientSecret == "" {
		return fmt.Errorf("Google ClientSecret is required")
	}
	if p.config.RedirectURL == "" {
		return fmt.Errorf("Google RedirectURL is required")
	}
	return nil
}

// GetAuthURL Google 인증 URL 생성
func (p *GoogleProvider) GetAuthURL(state string) string {
	params := map[string]string{
		"client_id":     p.config.ClientID,
		"redirect_uri":  p.config.RedirectURL,
		"response_type": "code",
		"scope":         "openid email profile",
		"state":         state,
		"access_type":   "offline",
		"prompt":        "consent",
	}

	return BuildURL("https://accounts.google.com/o/oauth2/v2/auth", params)
}

// ExchangeCode authorization code를 access token으로 교환
func (p *GoogleProvider) ExchangeCode(ctx context.Context, code string) (*TokenResponse, error) {
	tokenURL := "https://oauth2.googleapis.com/token"

	data := url.Values{
		"client_id":     {p.config.ClientID},
		"client_secret": {p.config.ClientSecret},
		"code":          {code},
		"grant_type":    {"authorization_code"},
		"redirect_uri":  {p.config.RedirectURL},
	}

	req, err := http.NewRequestWithContext(ctx, "POST", tokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return nil, fmt.Errorf("failed to create token request: %w", err)
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to exchange code: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("token exchange failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read token response: %w", err)
	}

	var tokenResp TokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return nil, fmt.Errorf("failed to parse token response: %w", err)
	}

	return &tokenResp, nil
}

// GetUserProfile access token으로 Google 사용자 프로필 정보 조회
func (p *GoogleProvider) GetUserProfile(ctx context.Context, accessToken string) (*UserProfile, error) {
	profileURL := "https://www.googleapis.com/oauth2/v2/userinfo"

	req, err := http.NewRequestWithContext(ctx, "GET", profileURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create profile request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+accessToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to get user profile: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("profile request failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read profile response: %w", err)
	}

	var googleProfile struct {
		ID            string `json:"id"`
		Email         string `json:"email"`
		VerifiedEmail bool   `json:"verified_email"`
		Name          string `json:"name"`
		GivenName     string `json:"given_name"`
		FamilyName    string `json:"family_name"`
		Picture       string `json:"picture"`
		Locale        string `json:"locale"`
	}

	if err := json.Unmarshal(body, &googleProfile); err != nil {
		return nil, fmt.Errorf("failed to parse profile response: %w", err)
	}

	// Google 프로필을 표준 UserProfile 형태로 변환
	profile := &UserProfile{
		ID:          googleProfile.ID,
		Email:       googleProfile.Email,
		FirstName:   googleProfile.GivenName,
		LastName:    googleProfile.FamilyName,
		DisplayName: googleProfile.Name,
		Avatar:      googleProfile.Picture,
		Provider:    "google",
		RawData: map[string]interface{}{
			"verified_email": googleProfile.VerifiedEmail,
			"locale":         googleProfile.Locale,
		},
	}

	return profile, nil
}