package com.signal.app.data.model.chat

import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import java.time.LocalDateTime

@Parcelize
data class ChatMessage(
    val id: String,
    val content: String,
    val senderId: String,
    val senderName: String,
    val timestamp: LocalDateTime,
    val type: MessageType = MessageType.TEXT,
    
    // 위치 정보
    val latitude: Double? = null,
    val longitude: Double? = null,
    val address: String? = null,
    
    // 빠른 응답
    val quickReplyType: QuickReplyType? = null,
    
    // 이미지
    val imageUrl: String? = null,
    
    // 읽음 상태
    val isRead: Boolean = false
) : Parcelable

enum class MessageType {
    TEXT,
    SYSTEM,
    IMAGE,
    LOCATION,
    QUICK_REPLY,
    COUNTDOWN,
    STATUS
}

enum class QuickReplyType {
    ARRIVED,
    LATE_5MIN,
    LATE_10MIN,
    LATE_15MIN,
    CANCEL,
    ON_WAY
}

enum class SignalStatus {
    ACTIVE,
    MEETING,
    COMPLETED,
    EXPIRED,
    CLOSED
}

@Parcelize
data class ChatRoom(
    val id: String,
    val name: String,
    val signalStatus: SignalStatus = SignalStatus.ACTIVE,
    val participantAvatars: List<String> = emptyList(),
    val onlineCount: Int = 0,
    val lastMessage: ChatMessage? = null
) : Parcelable

data class TypingUser(
    val userId: String,
    val username: String
)