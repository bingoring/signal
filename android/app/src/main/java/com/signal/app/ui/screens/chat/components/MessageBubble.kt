package com.signal.app.ui.screens.chat.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.signal.app.data.model.chat.*
import com.signal.app.ui.theme.*
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

@Composable
fun MessageBubble(
    message: ChatMessage,
    isMe: Boolean,
    onTap: (() -> Unit)? = null,
    onLongPress: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = tween(150),
        label = "message_scale"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                horizontal = ChatDimensions.PaddingMD,
                vertical = ChatDimensions.PaddingSM
            )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = if (isMe) Arrangement.End else Arrangement.Start
        ) {
            if (!isMe) {
                MessageAvatar(
                    senderName = message.senderName,
                    modifier = Modifier.padding(end = ChatDimensions.PaddingSM)
                )
            }
            
            Column(
                horizontalAlignment = if (isMe) Alignment.End else Alignment.Start,
                modifier = Modifier.widthIn(max = ChatDimensions.MessageBubbleMaxWidth)
            ) {
                if (!isMe) {
                    Text(
                        text = message.senderName,
                        style = ChatTextStyles.TimestampText.copy(
                            color = ChatColors.TextSecondary
                        ),
                        modifier = Modifier.padding(
                            start = ChatDimensions.PaddingMD,
                            bottom = 4.dp
                        )
                    )
                }
                
                Box(
                    modifier = Modifier
                        .scale(scale)
                        .pointerInput(Unit) {
                            detectTapGestures(
                                onPress = {
                                    isPressed = true
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    tryAwaitRelease()
                                    isPressed = false
                                },
                                onTap = { onTap?.invoke() },
                                onLongPress = {
                                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                                    onLongPress?.invoke()
                                }
                            )
                        }
                ) {
                    MessageContent(
                        message = message,
                        isMe = isMe
                    )
                }
                
                Spacer(modifier = Modifier.height(4.dp))
                
                MessageInfo(
                    message = message,
                    isMe = isMe
                )
            }
            
            if (isMe) {
                MessageAvatar(
                    senderName = "나",
                    modifier = Modifier.padding(start = ChatDimensions.PaddingSM)
                )
            }
        }
    }
}

@Composable
private fun MessageContent(
    message: ChatMessage,
    isMe: Boolean
) {
    when (message.type) {
        MessageType.TEXT -> TextMessageBubble(message, isMe)
        MessageType.LOCATION -> LocationMessageCard(message, isMe)
        MessageType.QUICK_REPLY -> QuickReplyMessageChip(message, isMe)
        MessageType.SYSTEM -> SystemMessageBubble(message)
        MessageType.COUNTDOWN -> CountdownMessageBubble(message)
        MessageType.STATUS -> StatusMessageBubble(message)
        MessageType.IMAGE -> ImageMessageBubble(message, isMe)
    }
}

@Composable
private fun TextMessageBubble(
    message: ChatMessage,
    isMe: Boolean
) {
    Box(
        modifier = Modifier
            .background(
                color = if (isMe) ChatColors.MyMessage else ChatColors.OtherMessage,
                shape = getMessageBubbleShape(isMe)
            )
            .shadow(
                elevation = ChatShadows.Card,
                shape = getMessageBubbleShape(isMe),
                spotColor = ChatShadows.SoftColor
            )
            .padding(ChatDimensions.PaddingMD)
    ) {
        Text(
            text = message.content,
            style = ChatTextStyles.MessageText.copy(
                color = if (isMe) ChatColors.TextOnPrimary else ChatColors.TextPrimary
            )
        )
    }
}

@Composable
private fun LocationMessageCard(
    message: ChatMessage,
    isMe: Boolean
) {
    Card(
        modifier = Modifier.width(250.dp),
        colors = CardDefaults.cardColors(
            containerColor = ChatColors.LocationBackground
        ),
        shape = RoundedCornerShape(ChatDimensions.RadiusMD),
        elevation = CardDefaults.cardElevation(
            defaultElevation = ChatShadows.Card
        )
    ) {
        Column {
            // 지도 미리보기
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .background(
                        color = ChatColors.LocationBackground.copy(alpha = 0.3f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(32.dp)
                    )
                    
                    Spacer(modifier = Modifier.height(ChatDimensions.PaddingSM))
                    
                    Text(
                        text = "위치 공유",
                        style = ChatTextStyles.MessageText.copy(
                            color = Color.White
                        )
                    )
                }
            }
            
            // 주소 정보
            Column(
                modifier = Modifier.padding(ChatDimensions.PaddingMD)
            ) {
                message.address?.let { address ->
                    Text(
                        text = address,
                        style = ChatTextStyles.MessageText.copy(
                            color = Color.White
                        )
                    )
                }
                
                if (message.latitude != null && message.longitude != null) {
                    Text(
                        text = "${String.format("%.6f", message.latitude)}, ${String.format("%.6f", message.longitude)}",
                        style = ChatTextStyles.TimestampText.copy(
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    )
                }
                
                Spacer(modifier = Modifier.height(ChatDimensions.PaddingSM))
                
                // 위치 보기 버튼
                Surface(
                    color = Color.White,
                    shape = RoundedCornerShape(ChatDimensions.RadiusSM),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(
                            horizontal = ChatDimensions.PaddingMD,
                            vertical = ChatDimensions.PaddingSM
                        ),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Map,
                            contentDescription = null,
                            tint = ChatColors.LocationBackground,
                            modifier = Modifier.size(16.dp)
                        )
                        
                        Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
                        
                        Text(
                            text = "위치 보기",
                            style = ChatTextStyles.SystemText.copy(
                                color = ChatColors.LocationBackground
                            )
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickReplyMessageChip(
    message: ChatMessage,
    isMe: Boolean
) {
    Surface(
        color = getQuickReplyColor(message.quickReplyType),
        shape = RoundedCornerShape(ChatDimensions.RadiusXL),
        shadowElevation = ChatShadows.Card
    ) {
        Row(
            modifier = Modifier.padding(
                horizontal = ChatDimensions.PaddingMD,
                vertical = ChatDimensions.PaddingSM
            ),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = getQuickReplyIcon(message.quickReplyType),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp)
            )
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            Text(
                text = message.content,
                style = ChatTextStyles.QuickReplyText
            )
        }
    }
}

@Composable
private fun SystemMessageBubble(
    message: ChatMessage
) {
    Surface(
        color = ChatColors.SystemMessage,
        shape = RoundedCornerShape(ChatDimensions.RadiusMD)
    ) {
        Row(
            modifier = Modifier.padding(ChatDimensions.PaddingMD),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = null,
                tint = ChatColors.Primary,
                modifier = Modifier.size(16.dp)
            )
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            Text(
                text = message.content,
                style = ChatTextStyles.SystemText.copy(
                    color = ChatColors.Primary,
                    textAlign = TextAlign.Center
                ),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun CountdownMessageBubble(
    message: ChatMessage
) {
    Surface(
        modifier = Modifier
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        ChatColors.Accent.copy(alpha = 0.1f),
                        ChatColors.Primary.copy(alpha = 0.1f)
                    )
                ),
                shape = RoundedCornerShape(ChatDimensions.RadiusMD)
            )
            .border(
                width = 1.dp,
                color = ChatColors.Accent.copy(alpha = 0.3f),
                shape = RoundedCornerShape(ChatDimensions.RadiusMD)
            ),
        color = Color.Transparent,
        shape = RoundedCornerShape(ChatDimensions.RadiusMD)
    ) {
        Row(
            modifier = Modifier.padding(ChatDimensions.PaddingMD),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Timer,
                contentDescription = null,
                tint = ChatColors.Accent,
                modifier = Modifier.size(18.dp)
            )
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            Text(
                text = message.content,
                style = ChatTextStyles.SystemText.copy(
                    color = ChatColors.Accent,
                    textAlign = TextAlign.Center
                ),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun StatusMessageBubble(
    message: ChatMessage
) {
    Surface(
        color = ChatColors.Online.copy(alpha = 0.1f),
        shape = RoundedCornerShape(ChatDimensions.RadiusMD),
        border = BorderStroke(
            width = 1.dp,
            color = ChatColors.Online.copy(alpha = 0.3f)
        )
    ) {
        Row(
            modifier = Modifier.padding(ChatDimensions.PaddingMD),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.CheckCircle,
                contentDescription = null,
                tint = ChatColors.Online,
                modifier = Modifier.size(18.dp)
            )
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            Text(
                text = message.content,
                style = ChatTextStyles.SystemText.copy(
                    color = ChatColors.Online,
                    textAlign = TextAlign.Center
                ),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun ImageMessageBubble(
    message: ChatMessage,
    isMe: Boolean
) {
    Card(
        modifier = Modifier.sizeIn(
            maxWidth = 250.dp,
            maxHeight = 300.dp
        ),
        shape = getMessageBubbleShape(isMe),
        elevation = CardDefaults.cardElevation(
            defaultElevation = ChatShadows.Card
        )
    ) {
        if (!message.imageUrl.isNullOrEmpty()) {
            AsyncImage(
                model = message.imageUrl,
                contentDescription = "이미지",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .height(120.dp)
                    .background(ChatColors.OtherMessage),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Default.BrokenImage,
                        contentDescription = null,
                        tint = ChatColors.TextSecondary,
                        modifier = Modifier.size(32.dp)
                    )
                    
                    Spacer(modifier = Modifier.height(ChatDimensions.PaddingSM))
                    
                    Text(
                        text = "이미지를 로드할 수 없습니다",
                        style = ChatTextStyles.SystemText
                    )
                }
            }
        }
    }
}

@Composable
private fun MessageAvatar(
    senderName: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(ChatDimensions.AvatarSM)
            .background(
                color = if (senderName == "나") {
                    ChatColors.Primary.copy(alpha = 0.1f)
                } else {
                    ChatColors.TextSecondary.copy(alpha = 0.1f)
                },
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = if (senderName.isNotEmpty()) senderName.first().toString().uppercase() else "?",
            style = ChatTextStyles.TimestampText.copy(
                color = if (senderName == "나") ChatColors.Primary else ChatColors.TextSecondary
            )
        )
    }
}

@Composable
private fun MessageInfo(
    message: ChatMessage,
    isMe: Boolean
) {
    Row(
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = formatTimestamp(message.timestamp),
            style = ChatTextStyles.TimestampText
        )
        
        if (isMe) {
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            ReadStatusIndicator(message.isRead)
        }
    }
}

@Composable
private fun ReadStatusIndicator(
    isRead: Boolean
) {
    val borderColor = if (isRead) ChatColors.Primary else ChatColors.TextSecondary
    val fillColor = if (isRead) ChatColors.Primary else Color.Transparent
    
    Box(
        modifier = Modifier
            .size(14.dp)
            .border(
                width = if (isRead) 1.5.dp else 1.dp,
                color = borderColor,
                shape = CircleShape
            )
            .background(
                color = fillColor,
                shape = CircleShape
            )
    ) {
        if (isRead) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(2.dp)
                    .background(
                        color = ChatColors.Primary,
                        shape = CircleShape
                    )
            )
        }
    }
}

private fun getMessageBubbleShape(isMe: Boolean): RoundedCornerShape {
    val radius = ChatDimensions.RadiusLG
    
    return if (isMe) {
        RoundedCornerShape(
            topStart = radius,
            topEnd = radius,
            bottomStart = radius,
            bottomEnd = 8.dp
        )
    } else {
        RoundedCornerShape(
            topStart = radius,
            topEnd = radius,
            bottomStart = 8.dp,
            bottomEnd = radius
        )
    }
}

private fun getQuickReplyColor(type: QuickReplyType?): Color {
    return when (type) {
        QuickReplyType.ARRIVED -> ChatColors.Online
        QuickReplyType.LATE_5MIN, QuickReplyType.LATE_10MIN, QuickReplyType.LATE_15MIN -> ChatColors.Away
        QuickReplyType.CANCEL -> ChatColors.Accent
        QuickReplyType.ON_WAY -> ChatColors.Primary
        null -> ChatColors.QuickReplyBackground
    }
}

private fun getQuickReplyIcon(type: QuickReplyType?): ImageVector {
    return when (type) {
        QuickReplyType.ARRIVED -> Icons.Default.LocationOn
        QuickReplyType.LATE_5MIN, QuickReplyType.LATE_10MIN, QuickReplyType.LATE_15MIN -> Icons.Default.AccessTime
        QuickReplyType.CANCEL -> Icons.Default.Cancel
        QuickReplyType.ON_WAY -> Icons.Default.DirectionsRun
        null -> Icons.Default.Message
    }
}

private fun formatTimestamp(timestamp: LocalDateTime): String {
    val now = LocalDateTime.now()
    val days = ChronoUnit.DAYS.between(timestamp, now)
    val hours = ChronoUnit.HOURS.between(timestamp, now)
    val minutes = ChronoUnit.MINUTES.between(timestamp, now)
    
    return when {
        days > 0 -> "${days}일 전"
        hours > 0 -> "${hours}시간 전"
        minutes > 0 -> "${minutes}분 전"
        else -> "방금 전"
    }
}