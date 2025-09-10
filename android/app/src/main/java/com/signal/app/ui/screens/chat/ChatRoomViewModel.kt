package com.signal.app.ui.screens.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.data.model.chat.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import javax.inject.Inject

data class ChatRoomUiState(
    val roomId: String = "",
    val roomName: String = "채팅방",
    val signalStatus: SignalStatus = SignalStatus.ACTIVE,
    val participantAvatars: List<String> = emptyList(),
    val onlineCount: Int = 0,
    val currentUserId: String = "current_user",
    val isLoading: Boolean = false,
    val isConnected: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class ChatRoomViewModel @Inject constructor(
    // TODO: Inject WebSocketService, ChatRepository when available
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ChatRoomUiState())
    val uiState: StateFlow<ChatRoomUiState> = _uiState.asStateFlow()
    
    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()
    
    private val _typingUsers = MutableStateFlow<List<TypingUser>>(emptyList())
    val typingUsers: StateFlow<List<TypingUser>> = _typingUsers.asStateFlow()
    
    fun joinRoom(roomId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(
                roomId = roomId,
                isLoading = true
            ) }
            
            try {
                // TODO: Connect to WebSocket
                // TODO: Join room via API
                
                // Simulate room joining
                _uiState.update { it.copy(
                    roomName = "시그널 모임 채팅",
                    signalStatus = SignalStatus.ACTIVE,
                    participantAvatars = listOf(
                        "https://example.com/avatar1.jpg",
                        "https://example.com/avatar2.jpg",
                        "https://example.com/avatar3.jpg"
                    ),
                    onlineCount = 5,
                    isLoading = false,
                    isConnected = true
                ) }
                
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    isLoading = false,
                    isConnected = false,
                    error = e.message
                ) }
            }
        }
    }
    
    fun loadMessages() {
        viewModelScope.launch {
            try {
                // TODO: Load messages from API
                // For now, use sample data
                _messages.value = SampleData.getSampleMessages()
                
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    error = e.message
                ) }
            }
        }
    }
    
    fun sendMessage(content: String) {
        if (content.trim().isEmpty()) return
        
        viewModelScope.launch {
            try {
                val newMessage = ChatMessage(
                    id = System.currentTimeMillis().toString(),
                    content = content.trim(),
                    senderId = _uiState.value.currentUserId,
                    senderName = "나",
                    timestamp = LocalDateTime.now(),
                    type = MessageType.TEXT,
                    isRead = false
                )
                
                // Add message locally first (optimistic update)
                _messages.update { currentMessages ->
                    currentMessages + newMessage
                }
                
                // TODO: Send message via WebSocket
                // webSocketService.sendMessage(newMessage)
                
                // Simulate typing stop
                simulateTypingStop()
                
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    error = e.message
                ) }
            }
        }
    }
    
    fun sendQuickReply(type: QuickReplyType) {
        val content = when (type) {
            QuickReplyType.ARRIVED -> "도착했어요"
            QuickReplyType.ON_WAY -> "가는 중이에요"
            QuickReplyType.LATE_5MIN -> "5분 늦을게요"
            QuickReplyType.LATE_10MIN -> "10분 늦을게요"
            QuickReplyType.LATE_15MIN -> "15분 늦을게요"
            QuickReplyType.CANCEL -> "취소할게요"
        }
        
        viewModelScope.launch {
            try {
                val newMessage = ChatMessage(
                    id = System.currentTimeMillis().toString(),
                    content = content,
                    senderId = _uiState.value.currentUserId,
                    senderName = "나",
                    timestamp = LocalDateTime.now(),
                    type = MessageType.QUICK_REPLY,
                    quickReplyType = type,
                    isRead = false
                )
                
                _messages.update { currentMessages ->
                    currentMessages + newMessage
                }
                
                // TODO: Send quick reply via WebSocket
                
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    error = e.message
                ) }
            }
        }
    }
    
    fun shareLocation() {
        viewModelScope.launch {
            try {
                // TODO: Get actual location
                val newMessage = ChatMessage(
                    id = System.currentTimeMillis().toString(),
                    content = "위치를 공유했습니다",
                    senderId = _uiState.value.currentUserId,
                    senderName = "나",
                    timestamp = LocalDateTime.now(),
                    type = MessageType.LOCATION,
                    latitude = 37.5665,
                    longitude = 126.9780,
                    address = "서울특별시 중구 을지로 100",
                    isRead = false
                )
                
                _messages.update { currentMessages ->
                    currentMessages + newMessage
                }
                
                // TODO: Send location via WebSocket
                
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    error = e.message
                ) }
            }
        }
    }
    
    fun showMessageOptions(message: ChatMessage) {
        // TODO: Show bottom sheet with message options
        // - Copy message
        // - Delete message (if own message)
        // - Reply to message
        // - Forward message
    }
    
    private fun simulateTypingStart() {
        viewModelScope.launch {
            _typingUsers.value = listOf(
                TypingUser("user1", "김철수")
            )
        }
    }
    
    private fun simulateTypingStop() {
        viewModelScope.launch {
            _typingUsers.value = emptyList()
        }
    }
    
    // WebSocket connection management
    fun connectWebSocket() {
        viewModelScope.launch {
            try {
                // TODO: Implement WebSocket connection
                _uiState.update { it.copy(isConnected = true) }
                
            } catch (e: Exception) {
                _uiState.update { it.copy(
                    isConnected = false,
                    error = e.message
                ) }
            }
        }
    }
    
    fun disconnectWebSocket() {
        viewModelScope.launch {
            // TODO: Implement WebSocket disconnection
            _uiState.update { it.copy(isConnected = false) }
        }
    }
    
    override fun onCleared() {
        super.onCleared()
        disconnectWebSocket()
    }
}