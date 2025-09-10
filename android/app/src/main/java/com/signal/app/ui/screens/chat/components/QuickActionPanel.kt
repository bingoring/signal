package com.signal.app.ui.screens.chat.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import com.signal.app.data.model.chat.QuickReplyType
import com.signal.app.ui.theme.*

@Composable
fun QuickActionPanel(
    isVisible: Boolean,
    onQuickReply: ((QuickReplyType) -> Unit)? = null,
    onLocationShare: (() -> Unit)? = null,
    onImagePicker: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current

    AnimatedVisibility(
        visible = isVisible,
        enter = slideInVertically(
            initialOffsetY = { it },
            animationSpec = tween(
                durationMillis = 300,
                easing = LinearOutSlowInEasing
            )
        ) + fadeIn(
            animationSpec = tween(
                durationMillis = 200,
                easing = LinearEasing
            )
        ),
        exit = slideOutVertically(
            targetOffsetY = { it },
            animationSpec = tween(
                durationMillis = 200,
                easing = FastOutLinearInEasing
            )
        ) + fadeOut(
            animationSpec = tween(
                durationMillis = 150
            )
        ),
        modifier = modifier
    ) {
        Surface(
            color = ChatColors.Surface,
            shadowElevation = ChatShadows.Popup,
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(ChatDimensions.PaddingMD)
            ) {
                // Quick Reply Section
                QuickReplySection(
                    onQuickReply = { type ->
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onQuickReply?.invoke(type)
                    }
                )
                
                HorizontalDivider(
                    modifier = Modifier.padding(vertical = ChatDimensions.PaddingSM),
                    color = ChatColors.Divider
                )
                
                // Media Actions Section
                MediaActionsSection(
                    onLocationShare = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onLocationShare?.invoke()
                    },
                    onImagePicker = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onImagePicker?.invoke()
                    }
                )
            }
        }
    }
}

@Composable
private fun QuickReplySection(
    onQuickReply: (QuickReplyType) -> Unit
) {
    Column {
        Text(
            text = "빠른 응답",
            style = ChatTextStyles.SystemText.copy(
                color = ChatColors.TextPrimary
            ),
            modifier = Modifier.padding(bottom = ChatDimensions.PaddingSM)
        )
        
        Column(
            verticalArrangement = Arrangement.spacedBy(ChatDimensions.PaddingSM)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(ChatDimensions.PaddingSM)
            ) {
                QuickReplyChip(
                    text = "도착했어요",
                    icon = Icons.Default.LocationOn,
                    color = ChatColors.Online,
                    onClick = { onQuickReply(QuickReplyType.ARRIVED) },
                    modifier = Modifier.weight(1f)
                )
                
                QuickReplyChip(
                    text = "가는 중",
                    icon = Icons.Default.DirectionsRun,
                    color = ChatColors.Primary,
                    onClick = { onQuickReply(QuickReplyType.ON_WAY) },
                    modifier = Modifier.weight(1f)
                )
            }
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(ChatDimensions.PaddingSM)
            ) {
                QuickReplyChip(
                    text = "5분 늦음",
                    icon = Icons.Default.AccessTime,
                    color = ChatColors.Away,
                    onClick = { onQuickReply(QuickReplyType.LATE_5MIN) },
                    modifier = Modifier.weight(1f)
                )
                
                QuickReplyChip(
                    text = "15분 늦음",
                    icon = Icons.Default.AccessTime,
                    color = ChatColors.Away,
                    onClick = { onQuickReply(QuickReplyType.LATE_15MIN) },
                    modifier = Modifier.weight(1f)
                )
            }
            
            QuickReplyChip(
                text = "취소할게요",
                icon = Icons.Default.Cancel,
                color = ChatColors.Accent,
                onClick = { onQuickReply(QuickReplyType.CANCEL) },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun QuickReplyChip(
    text: String,
    icon: ImageVector,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = tween(150),
        label = "chip_scale"
    )

    Surface(
        onClick = onClick,
        modifier = modifier.scale(scale),
        color = color.copy(alpha = 0.1f),
        shape = RoundedCornerShape(ChatDimensions.RadiusXL),
        border = BorderStroke(
            width = 1.dp,
            color = color.copy(alpha = 0.3f)
        )
    ) {
        Row(
            modifier = Modifier
                .padding(
                    horizontal = ChatDimensions.PaddingMD,
                    vertical = ChatDimensions.PaddingSM
                )
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) {
                    onClick()
                },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(16.dp)
            )
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            Text(
                text = text,
                style = ChatTextStyles.SystemText.copy(
                    color = color
                )
            )
        }
    }
}

@Composable
private fun MediaActionsSection(
    onLocationShare: () -> Unit,
    onImagePicker: () -> Unit
) {
    Column {
        Text(
            text = "미디어 및 위치",
            style = ChatTextStyles.SystemText.copy(
                color = ChatColors.TextPrimary
            ),
            modifier = Modifier.padding(bottom = ChatDimensions.PaddingSM)
        )
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(ChatDimensions.PaddingMD)
        ) {
            MediaActionButton(
                label = "위치 공유",
                icon = Icons.Default.LocationOn,
                color = ChatColors.LocationBackground,
                onClick = onLocationShare,
                modifier = Modifier.weight(1f)
            )
            
            MediaActionButton(
                label = "사진",
                icon = Icons.Default.PhotoCamera,
                color = ChatColors.Primary,
                onClick = onImagePicker,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun MediaActionButton(
    label: String,
    icon: ImageVector,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = tween(150),
        label = "media_button_scale"
    )

    Surface(
        onClick = onClick,
        modifier = modifier.scale(scale),
        color = color.copy(alpha = 0.1f),
        shape = RoundedCornerShape(ChatDimensions.RadiusMD),
        border = BorderStroke(
            width = 1.dp,
            color = color.copy(alpha = 0.3f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(ChatDimensions.PaddingMD)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) {
                    onClick()
                },
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .size(ChatDimensions.QuickActionSize)
                    .background(
                        color = color,
                        shape = CircleShape
                    )
                    .shadow(
                        elevation = ChatShadows.Card,
                        shape = CircleShape,
                        spotColor = ChatShadows.SoftColor
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }
            
            Spacer(modifier = Modifier.height(ChatDimensions.PaddingSM))
            
            Text(
                text = label,
                style = ChatTextStyles.SystemText.copy(
                    color = color
                )
            )
        }
    }
}