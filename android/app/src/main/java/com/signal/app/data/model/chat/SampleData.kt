package com.signal.app.data.model.chat

import java.time.LocalDateTime

object SampleData {
    fun getSampleMessages(): List<ChatMessage> {
        return listOf(
            ChatMessage(
                id = "1",
                content = "안녕하세요! 오늘 모임에 참석할 예정입니다.",
                senderId = "user1",
                senderName = "김철수",
                timestamp = LocalDateTime.now().minusMinutes(30),
                type = MessageType.TEXT,
                isRead = true
            ),
            ChatMessage(
                id = "2",
                content = "네, 저도 참석하겠습니다!",
                senderId = "current_user",
                senderName = "나",
                timestamp = LocalDateTime.now().minusMinutes(25),
                type = MessageType.TEXT,
                isRead = true
            ),
            ChatMessage(
                id = "3",
                content = "서울특별시 중구 을지로 100",
                senderId = "user2",
                senderName = "박영희",
                timestamp = LocalDateTime.now().minusMinutes(20),
                type = MessageType.LOCATION,
                latitude = 37.5665,
                longitude = 126.9780,
                address = "서울특별시 중구 을지로 100",
                isRead = true
            ),
            ChatMessage(
                id = "4",
                content = "김철수님이 채팅방에 입장하셨습니다.",
                senderId = "system",
                senderName = "시스템",
                timestamp = LocalDateTime.now().minusMinutes(15),
                type = MessageType.SYSTEM
            ),
            ChatMessage(
                id = "5",
                content = "도착했어요",
                senderId = "user1",
                senderName = "김철수",
                timestamp = LocalDateTime.now().minusMinutes(10),
                type = MessageType.QUICK_REPLY,
                quickReplyType = QuickReplyType.ARRIVED,
                isRead = true
            ),
            ChatMessage(
                id = "6",
                content = "5분 늦을게요 😅",
                senderId = "user3",
                senderName = "이민수",
                timestamp = LocalDateTime.now().minusMinutes(5),
                type = MessageType.QUICK_REPLY,
                quickReplyType = QuickReplyType.LATE_5MIN,
                isRead = false
            ),
            ChatMessage(
                id = "7",
                content = "모든 분들 오셨네요! 즐거운 시간 보내세요!",
                senderId = "current_user",
                senderName = "나",
                timestamp = LocalDateTime.now().minusMinutes(2),
                type = MessageType.TEXT,
                isRead = false
            )
        )
    }
}