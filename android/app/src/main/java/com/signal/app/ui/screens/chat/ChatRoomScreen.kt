package com.signal.app.ui.screens.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.signal.app.data.model.chat.*
import com.signal.app.ui.screens.chat.components.*
import com.signal.app.ui.theme.*
import java.time.LocalDateTime

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatRoomScreen(
    roomId: String,
    onBackPressed: () -> Unit,
    viewModel: ChatRoomViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val messages by viewModel.messages.collectAsState()
    val typingUsers by viewModel.typingUsers.collectAsState()
    val haptic = LocalHapticFeedback.current
    val listState = rememberLazyListState()
    
    LaunchedEffect(roomId) {
        viewModel.joinRoom(roomId)
        viewModel.loadMessages()
    }
    
    // Auto scroll to bottom when new messages arrive
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = ChatColors.Background,
        topBar = {
            InstagramStyleAppBar(
                signalTitle = uiState.roomName,
                participantAvatars = uiState.participantAvatars,
                status = uiState.signalStatus,
                onlineCount = uiState.onlineCount,
                onBackPressed = onBackPressed,
                onInfoPressed = {
                    // TODO: Show room info
                },
                onMenuPressed = {
                    // TODO: Show menu
                }
            )
        },
        bottomBar = {
            Column {
                // Typing indicator
                if (typingUsers.isNotEmpty()) {
                    TypingIndicator(
                        typingUsers = typingUsers.map { it.username },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                
                // Message input
                EnhancedMessageInput(
                    onSendMessage = { content ->
                        viewModel.sendMessage(content)
                        haptic.performHapticFeedback(HapticFeedbackType.LightImpact)
                    },
                    onQuickReply = { type ->
                        viewModel.sendQuickReply(type)
                        haptic.performHapticFeedback(HapticFeedbackType.LightImpact)
                    },
                    onLocationShare = {
                        viewModel.shareLocation()
                        haptic.performHapticFeedback(HapticFeedbackType.LightImpact)
                    },
                    onImagePicker = {
                        // TODO: Implement image picker
                        haptic.performHapticFeedback(HapticFeedbackType.LightImpact)
                    }
                )
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading -> {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center),
                        color = ChatColors.Primary
                    )
                }
                
                messages.isEmpty() -> {
                    EmptyMessagesView(
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
                
                else -> {
                    MessagesList(
                        messages = messages,
                        currentUserId = uiState.currentUserId,
                        listState = listState,
                        onMessageTap = { message ->
                            // TODO: Handle message tap
                        },
                        onMessageLongPress = { message ->
                            viewModel.showMessageOptions(message)
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        }
                    )
                }
            }
            
            // Connection status
            if (!uiState.isConnected) {
                ConnectionStatusBanner(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                )
            }
        }
    }
}

@Composable
private fun MessagesList(
    messages: List<ChatMessage>,
    currentUserId: String,
    listState: LazyListState,
    onMessageTap: (ChatMessage) -> Unit,
    onMessageLongPress: (ChatMessage) -> Unit
) {
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            horizontal = ChatDimensions.PaddingXS,
            vertical = ChatDimensions.PaddingSM
        )
    ) {
        items(messages) { message ->
            MessageBubble(
                message = message,
                isMe = message.senderId == currentUserId,
                onTap = { onMessageTap(message) },
                onLongPress = { onMessageLongPress(message) }
            )
        }
    }
}

@Composable
private fun EmptyMessagesView(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Chat,
            contentDescription = null,
            tint = ChatColors.TextSecondary,
            modifier = Modifier.size(64.dp)
        )
        
        Spacer(modifier = Modifier.height(ChatDimensions.PaddingMD))
        
        Text(
            text = "채팅을 시작해보세요!",
            style = ChatTextStyles.SystemText.copy(
                color = ChatColors.TextSecondary
            )
        )
    }
}

@Composable
private fun ConnectionStatusBanner(
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = ChatColors.Away,
        shadowElevation = ChatShadows.Card
    ) {
        Row(
            modifier = Modifier.padding(
                horizontal = ChatDimensions.PaddingMD,
                vertical = ChatDimensions.PaddingSM
            ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                color = ChatColors.TextOnPrimary,
                strokeWidth = 2.dp
            )
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            Text(
                text = "연결 중...",
                style = ChatTextStyles.SystemText.copy(
                    color = ChatColors.TextOnPrimary
                )
            )
        }
    }
}