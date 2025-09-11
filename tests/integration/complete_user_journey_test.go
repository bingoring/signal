package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

// TestCompleteUserJourney tests the complete user journey from registration to chat completion
func (s *IntegrationTestSuite) TestCompleteUserJourney() {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()

	// Step 1: User Registration and Authentication
	s.T().Log("Step 1: User Registration and Authentication")
	
	// Create test users
	creator := s.createAndAuthenticateUser("test-creator@signal.com", "Test Creator", 37.4981, 127.0276)
	participant1 := s.createAndAuthenticateUser("test-participant1@signal.com", "Test Participant 1", 37.4985, 127.0280)
	participant2 := s.createAndAuthenticateUser("test-participant2@signal.com", "Test Participant 2", 37.4975, 127.0272)
	
	s.Require().NotEmpty(creator.Token, "Creator authentication failed")
	s.Require().NotEmpty(participant1.Token, "Participant 1 authentication failed")
	s.Require().NotEmpty(participant2.Token, "Participant 2 authentication failed")
	
	// Step 2: Signal Creation
	s.T().Log("Step 2: Signal Creation")
	
	signal := s.createSignalWithAuth(creator.Token, CreateSignalRequest{
		Title:       "Test Integration Signal",
		Description: "Complete user journey test signal",
		Category:    "테스트",
		Latitude:    37.4981,
		Longitude:   127.0276,
		MaxCount:    3,
		MeetTime:    time.Now().Add(2 * time.Hour),
	})
	
	s.Require().NotZero(signal.ID, "Signal creation failed")
	s.T().Logf("Created signal with ID: %d", signal.ID)
	
	// Step 3: Signal Discovery
	s.T().Log("Step 3: Signal Discovery")
	
	// Participants discover the signal
	discoveredSignals := s.searchSignalsWithAuth(participant1.Token, SearchRequest{
		Latitude:  37.4985,
		Longitude: 127.0280,
		Radius:    1000, // 1km
		Category:  "테스트",
	})
	
	s.Require().NotEmpty(discoveredSignals, "Signal discovery failed")
	
	var targetSignal *TestSignal
	for _, sig := range discoveredSignals {
		if sig.ID == signal.ID {
			targetSignal = &sig
			break
		}
	}
	s.Require().NotNil(targetSignal, "Created signal not found in search results")
	
	// Step 4: Participation Requests
	s.T().Log("Step 4: Participation Requests")
	
	// Participants request to join
	joinReq1 := s.requestToJoinSignal(participant1.Token, signal.ID)
	s.Require().True(joinReq1.Success, "Participant 1 join request failed")
	
	joinReq2 := s.requestToJoinSignal(participant2.Token, signal.ID)
	s.Require().True(joinReq2.Success, "Participant 2 join request failed")
	
	// Step 5: Approval Process
	s.T().Log("Step 5: Approval Process")
	
	// Creator approves participants
	approval1 := s.approveParticipant(creator.Token, signal.ID, participant1.ID)
	s.Require().True(approval1.Success, "Participant 1 approval failed")
	
	approval2 := s.approveParticipant(creator.Token, signal.ID, participant2.ID)
	s.Require().True(approval2.Success, "Participant 2 approval failed")
	
	// Verify chat room was created
	time.Sleep(2 * time.Second) // Allow time for chat room creation
	
	chatRoom := s.getChatRoomForSignal(creator.Token, signal.ID)
	s.Require().NotNil(chatRoom, "Chat room was not created after approval")
	s.Require().Equal("active", chatRoom.Status, "Chat room status should be active")
	
	// Step 6: Real-time Chat
	s.T().Log("Step 6: Real-time Chat")
	
	// Establish WebSocket connections for all participants
	creatorWS := s.connectToChat(creator.Token, chatRoom.ID)
	participant1WS := s.connectToChat(participant1.Token, chatRoom.ID)
	participant2WS := s.connectToChat(participant2.Token, chatRoom.ID)
	
	defer creatorWS.Close()
	defer participant1WS.Close()
	defer participant2WS.Close()
	
	// Test text messaging
	s.sendChatMessage(creatorWS, ChatMessage{
		Type:    "text",
		Content: "안녕하세요! 모임을 시작해보겠습니다.",
	})
	
	// Verify message received by participants
	msg1 := s.receiveChatMessage(participant1WS, 5*time.Second)
	msg2 := s.receiveChatMessage(participant2WS, 5*time.Second)
	
	s.Require().Equal("안녕하세요! 모임을 시작해보겠습니다.", msg1.Content)
	s.Require().Equal("안녕하세요! 모임을 시작해보겠습니다.", msg2.Content)
	
	// Test location sharing
	s.sendChatMessage(participant1WS, ChatMessage{
		Type:    "location",
		Content: "현재 위치를 공유합니다.",
		Location: &Location{
			Latitude:  37.4985,
			Longitude: 127.0280,
		},
	})
	
	locationMsg := s.receiveChatMessage(creatorWS, 5*time.Second)
	s.Require().Equal("location", locationMsg.Type)
	s.Require().NotNil(locationMsg.Location)
	
	// Test quick reply
	s.sendChatMessage(participant2WS, ChatMessage{
		Type:    "quick_reply",
		Content: "도착했어요",
	})
	
	quickReplyMsg := s.receiveChatMessage(creatorWS, 5*time.Second)
	s.Require().Equal("quick_reply", quickReplyMsg.Type)
	s.Require().Equal("도착했어요", quickReplyMsg.Content)
	
	// Step 7: Meeting Execution
	s.T().Log("Step 7: Meeting Execution")
	
	// Update meeting status
	statusUpdate := s.updateSignalStatus(creator.Token, signal.ID, "meeting")
	s.Require().True(statusUpdate.Success, "Failed to update signal status to meeting")
	
	// Send system message about meeting start
	s.sendChatMessage(creatorWS, ChatMessage{
		Type:    "system",
		Content: "모임이 시작되었습니다!",
	})
	
	// Step 8: Meeting Completion
	s.T().Log("Step 8: Meeting Completion")
	
	// Mark meeting as completed
	completion := s.completeSignal(creator.Token, signal.ID)
	s.Require().True(completion.Success, "Failed to complete signal")
	
	// Send completion message
	s.sendChatMessage(creatorWS, ChatMessage{
		Type:    "system",
		Content: "모임이 성공적으로 완료되었습니다. 24시간 후 채팅방이 삭제됩니다.",
	})
	
	// Verify all participants received completion message
	completionMsg1 := s.receiveChatMessage(participant1WS, 5*time.Second)
	completionMsg2 := s.receiveChatMessage(participant2WS, 5*time.Second)
	
	s.Require().Contains(completionMsg1.Content, "완료되었습니다")
	s.Require().Contains(completionMsg2.Content, "완료되었습니다")
	
	// Step 9: Verify Chat Room Expiry Setup
	s.T().Log("Step 9: Verify Chat Room Expiry Setup")
	
	updatedChatRoom := s.getChatRoomForSignal(creator.Token, signal.ID)
	s.Require().NotNil(updatedChatRoom, "Chat room should still exist")
	s.Require().Equal("completed", updatedChatRoom.Status, "Chat room status should be completed")
	
	expectedExpiry := time.Now().Add(24 * time.Hour)
	s.Require().WithinDuration(expectedExpiry, updatedChatRoom.ExpiresAt, 5*time.Minute, "Chat room expiry time incorrect")
	
	s.T().Log("Complete user journey test passed successfully!")
}

// Helper methods for the complete user journey test

type CreateSignalRequest struct {
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Category    string    `json:"category"`
	Latitude    float64   `json:"latitude"`
	Longitude   float64   `json:"longitude"`
	MaxCount    int       `json:"max_count"`
	MeetTime    time.Time `json:"meet_time"`
}

type SearchRequest struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Radius    int     `json:"radius"`
	Category  string  `json:"category"`
}

type JoinResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type ApprovalResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func (s *IntegrationTestSuite) createAndAuthenticateUser(email, name string, lat, lng float64) TestUser {
	// Create user registration request
	regReq := map[string]interface{}{
		"email":     email,
		"name":      name,
		"latitude":  lat,
		"longitude": lng,
	}
	
	reqBody, _ := json.Marshal(regReq)
	resp, err := s.httpClient.Post(s.baseURL+"/auth/register", "application/json", bytes.NewBuffer(reqBody))
	s.Require().NoError(err, "Failed to register user")
	defer resp.Body.Close()
	
	s.Require().Equal(http.StatusOK, resp.StatusCode, "User registration failed")
	
	var authResp struct {
		Token string   `json:"token"`
		User  TestUser `json:"user"`
	}
	
	err = json.NewDecoder(resp.Body).Decode(&authResp)
	s.Require().NoError(err, "Failed to decode auth response")
	
	authResp.User.Token = authResp.Token
	return authResp.User
}

func (s *IntegrationTestSuite) createSignalWithAuth(token string, req CreateSignalRequest) TestSignal {
	reqBody, _ := json.Marshal(req)
	
	httpReq, _ := http.NewRequest("POST", s.baseURL+"/signals", bytes.NewBuffer(reqBody))
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := s.httpClient.Do(httpReq)
	s.Require().NoError(err, "Failed to create signal")
	defer resp.Body.Close()
	
	s.Require().Equal(http.StatusCreated, resp.StatusCode, "Signal creation failed")
	
	var signal TestSignal
	err = json.NewDecoder(resp.Body).Decode(&signal)
	s.Require().NoError(err, "Failed to decode signal response")
	
	return signal
}

func (s *IntegrationTestSuite) searchSignalsWithAuth(token string, req SearchRequest) []TestSignal {
	url := fmt.Sprintf("%s/signals/search?lat=%f&lng=%f&radius=%d&category=%s", 
		s.baseURL, req.Latitude, req.Longitude, req.Radius, req.Category)
	
	httpReq, _ := http.NewRequest("GET", url, nil)
	httpReq.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := s.httpClient.Do(httpReq)
	s.Require().NoError(err, "Failed to search signals")
	defer resp.Body.Close()
	
	s.Require().Equal(http.StatusOK, resp.StatusCode, "Signal search failed")
	
	var signals []TestSignal
	err = json.NewDecoder(resp.Body).Decode(&signals)
	s.Require().NoError(err, "Failed to decode search response")
	
	return signals
}

func (s *IntegrationTestSuite) requestToJoinSignal(token string, signalID uint) JoinResponse {
	url := fmt.Sprintf("%s/signals/%d/join", s.baseURL, signalID)
	
	httpReq, _ := http.NewRequest("POST", url, nil)
	httpReq.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := s.httpClient.Do(httpReq)
	s.Require().NoError(err, "Failed to join signal")
	defer resp.Body.Close()
	
	var joinResp JoinResponse
	err = json.NewDecoder(resp.Body).Decode(&joinResp)
	s.Require().NoError(err, "Failed to decode join response")
	
	return joinResp
}

func (s *IntegrationTestSuite) approveParticipant(token string, signalID, participantID uint) ApprovalResponse {
	url := fmt.Sprintf("%s/signals/%d/participants/%d/approve", s.baseURL, signalID, participantID)
	
	httpReq, _ := http.NewRequest("POST", url, nil)
	httpReq.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := s.httpClient.Do(httpReq)
	s.Require().NoError(err, "Failed to approve participant")
	defer resp.Body.Close()
	
	var approvalResp ApprovalResponse
	err = json.NewDecoder(resp.Body).Decode(&approvalResp)
	s.Require().NoError(err, "Failed to decode approval response")
	
	return approvalResp
}

func (s *IntegrationTestSuite) getChatRoomForSignal(token string, signalID uint) *ChatRoom {
	url := fmt.Sprintf("%s/chat/rooms?signal_id=%d", s.baseURL, signalID)
	
	httpReq, _ := http.NewRequest("GET", url, nil)
	httpReq.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := s.httpClient.Do(httpReq)
	s.Require().NoError(err, "Failed to get chat room")
	defer resp.Body.Close()
	
	if resp.StatusCode == http.StatusNotFound {
		return nil
	}
	
	s.Require().Equal(http.StatusOK, resp.StatusCode, "Get chat room failed")
	
	var chatRoom ChatRoom
	err = json.NewDecoder(resp.Body).Decode(&chatRoom)
	s.Require().NoError(err, "Failed to decode chat room response")
	
	return &chatRoom
}

func (s *IntegrationTestSuite) connectToChat(token string, roomID uint) *websocket.Conn {
	url := fmt.Sprintf("%s/ws/chat/%d?token=%s", s.wsURL, roomID, token)
	
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	s.Require().NoError(err, "Failed to connect to WebSocket")
	
	return conn
}

func (s *IntegrationTestSuite) sendChatMessage(conn *websocket.Conn, msg ChatMessage) {
	err := conn.WriteJSON(msg)
	s.Require().NoError(err, "Failed to send chat message")
}

func (s *IntegrationTestSuite) receiveChatMessage(conn *websocket.Conn, timeout time.Duration) ChatMessage {
	conn.SetReadDeadline(time.Now().Add(timeout))
	
	var msg ChatMessage
	err := conn.ReadJSON(&msg)
	s.Require().NoError(err, "Failed to receive chat message")
	
	return msg
}

func (s *IntegrationTestSuite) updateSignalStatus(token string, signalID uint, status string) JoinResponse {
	reqBody := map[string]string{"status": status}
	body, _ := json.Marshal(reqBody)
	
	url := fmt.Sprintf("%s/signals/%d/status", s.baseURL, signalID)
	httpReq, _ := http.NewRequest("PUT", url, bytes.NewBuffer(body))
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+token)
	
	resp, err := s.httpClient.Do(httpReq)
	s.Require().NoError(err, "Failed to update signal status")
	defer resp.Body.Close()
	
	var updateResp JoinResponse
	err = json.NewDecoder(resp.Body).Decode(&updateResp)
	s.Require().NoError(err, "Failed to decode status update response")
	
	return updateResp
}

func (s *IntegrationTestSuite) completeSignal(token string, signalID uint) JoinResponse {
	return s.updateSignalStatus(token, signalID, "completed")
}