package com.signal.app.ui.screens.chat.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.signal.app.data.model.chat.QuickReplyType
import com.signal.app.ui.theme.*

@Composable
fun EnhancedMessageInput(
    onSendMessage: (String) -> Unit,
    onQuickReply: ((QuickReplyType) -> Unit)? = null,
    onLocationShare: (() -> Unit)? = null,
    onImagePicker: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    var textFieldValue by remember { mutableStateOf(TextFieldValue("")) }
    var isQuickActionPanelVisible by remember { mutableStateOf(false) }
    var isFocused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val haptic = LocalHapticFeedback.current
    
    val scaleAnimation by animateFloatAsState(
        targetValue = if (isFocused) 1.02f else 1f,
        animationSpec = tween(300),
        label = "input_scale"
    )
    
    val hasText = textFieldValue.text.isNotEmpty()
    
    val sendButtonScale by animateFloatAsState(
        targetValue = if (hasText) 1f else 0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "send_button_scale"
    )

    LaunchedEffect(isQuickActionPanelVisible) {
        if (isQuickActionPanelVisible && isFocused) {
            // Clear focus when quick action panel opens
        }
    }

    Column(
        modifier = modifier
    ) {
        // Quick Action Panel
        QuickActionPanel(
            isVisible = isQuickActionPanelVisible,
            onQuickReply = { type ->
                onQuickReply?.invoke(type)
                isQuickActionPanelVisible = false
            },
            onLocationShare = {
                onLocationShare?.invoke()
                isQuickActionPanelVisible = false
            },
            onImagePicker = {
                onImagePicker?.invoke()
                isQuickActionPanelVisible = false
            }
        )
        
        // Input Container
        Surface(
            color = ChatColors.Surface,
            shadowElevation = ChatShadows.Card,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(
                        horizontal = ChatDimensions.PaddingMD,
                        vertical = ChatDimensions.PaddingSM
                    ),
                verticalAlignment = Alignment.Bottom
            ) {
                // Quick Action Button
                QuickActionButton(
                    isExpanded = isQuickActionPanelVisible,
                    onClick = {
                        isQuickActionPanelVisible = !isQuickActionPanelVisible
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    }
                )
                
                Spacer(modifier = Modifier.width(ChatDimensions.PaddingMD))
                
                // Text Input
                MessageTextField(
                    value = textFieldValue,
                    onValueChange = { textFieldValue = it },
                    isFocused = isFocused,
                    scaleAnimation = scaleAnimation,
                    focusRequester = focusRequester,
                    onFocusChanged = { focused ->
                        isFocused = focused
                        if (focused) {
                            isQuickActionPanelVisible = false
                        }
                    },
                    modifier = Modifier.weight(1f)
                )
                
                Spacer(modifier = Modifier.width(ChatDimensions.PaddingMD))
                
                // Send Button
                SendButton(
                    hasText = hasText,
                    scale = sendButtonScale,
                    onClick = {
                        if (hasText) {
                            onSendMessage(textFieldValue.text)
                            textFieldValue = TextFieldValue("")
                            haptic.performHapticFeedback(HapticFeedbackType.LightImpact)
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun MessageTextField(
    value: TextFieldValue,
    onValueChange: (TextFieldValue) -> Unit,
    isFocused: Boolean,
    scaleAnimation: Float,
    focusRequester: FocusRequester,
    onFocusChanged: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val borderColor = if (isFocused) {
        ChatColors.Primary.copy(alpha = 0.3f)
    } else {
        ChatColors.Divider
    }
    
    Box(
        modifier = modifier
            .scale(scaleAnimation)
            .sizeIn(
                minHeight = ChatDimensions.InputFieldMinHeight,
                maxHeight = ChatDimensions.InputFieldMaxHeight
            )
            .background(
                color = ChatColors.Background,
                shape = RoundedCornerShape(ChatDimensions.RadiusLG)
            )
            .border(
                width = 1.5.dp,
                color = borderColor,
                shape = RoundedCornerShape(ChatDimensions.RadiusLG)
            )
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(ChatDimensions.PaddingMD),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = ChatTextStyles.InputText,
                cursorBrush = SolidColor(ChatColors.Primary),
                modifier = Modifier
                    .weight(1f)
                    .focusRequester(focusRequester)
                    .onFocusChanged { onFocusChanged(it.isFocused) },
                decorationBox = { innerTextField ->
                    if (value.text.isEmpty()) {
                        Text(
                            text = "메시지를 입력하세요...",
                            style = ChatTextStyles.InputHint
                        )
                    }
                    innerTextField()
                }
            )
            
            // Character counter for long messages
            if (value.text.length > 200) {
                Text(
                    text = "${value.text.length}/1000",
                    style = ChatTextStyles.TimestampText.copy(
                        color = if (value.text.length > 900) {
                            ChatColors.Accent
                        } else {
                            ChatColors.TextSecondary
                        },
                        fontSize = 10.sp
                    ),
                    modifier = Modifier.padding(start = ChatDimensions.PaddingSM)
                )
            }
        }
    }
}

@Composable
private fun QuickActionButton(
    isExpanded: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val rotationAnimation by animateFloatAsState(
        targetValue = if (isExpanded) 45f else 0f,
        animationSpec = tween(
            durationMillis = 300,
            easing = LinearOutSlowInEasing
        ),
        label = "rotation"
    )

    Box(
        modifier = modifier
            .size(ChatDimensions.QuickActionSize)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        ChatColors.GradientStart,
                        ChatColors.GradientMiddle,
                        ChatColors.GradientEnd
                    )
                ),
                shape = CircleShape
            )
            .shadow(
                elevation = ChatShadows.Card,
                shape = CircleShape,
                spotColor = ChatShadows.SoftColor
            )
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = if (isExpanded) Icons.Default.Close else Icons.Default.Add,
            contentDescription = if (isExpanded) "닫기" else "빠른 액션",
            tint = Color.White,
            modifier = Modifier
                .size(ChatDimensions.QuickActionIconSize)
                .rotate(rotationAnimation)
        )
    }
}

@Composable
private fun SendButton(
    hasText: Boolean,
    scale: Float,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(44.dp)
            .scale(scale)
            .background(
                brush = if (hasText) {
                    Brush.linearGradient(
                        colors = listOf(
                            ChatColors.GradientStart,
                            ChatColors.GradientMiddle,
                            ChatColors.GradientEnd
                        )
                    )
                } else {
                    Brush.linearGradient(
                        colors = listOf(
                            ChatColors.TextSecondary.copy(alpha = 0.3f),
                            ChatColors.TextSecondary.copy(alpha = 0.3f)
                        )
                    )
                },
                shape = CircleShape
            )
            .shadow(
                elevation = if (hasText) ChatShadows.Card else 0.dp,
                shape = CircleShape,
                spotColor = ChatShadows.SoftColor
            )
            .clickable(enabled = hasText) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = if (hasText) Icons.Default.Send else Icons.Default.Send,
            contentDescription = "전송",
            tint = if (hasText) Color.White else ChatColors.TextSecondary,
            modifier = Modifier.size(20.dp)
        )
    }
}

// Typing Indicator Component
@Composable
fun TypingIndicator(
    typingUsers: List<String>,
    modifier: Modifier = Modifier
) {
    if (typingUsers.isEmpty()) return
    
    val infiniteTransition = rememberInfiniteTransition(label = "typing")
    
    val dots = (0..2).map { index ->
        infiniteTransition.animateFloat(
            initialValue = 0.4f,
            targetValue = 1.0f,
            animationSpec = infiniteRepeatable(
                animation = tween(
                    durationMillis = 600,
                    delayMillis = index * 200,
                    easing = LinearEasing
                ),
                repeatMode = RepeatMode.Reverse
            ),
            label = "dot_$index"
        )
    }
    
    Surface(
        modifier = modifier.padding(
            horizontal = ChatDimensions.PaddingMD,
            vertical = ChatDimensions.PaddingSM
        ),
        color = ChatColors.Surface
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            Box(
                modifier = Modifier
                    .size(ChatDimensions.AvatarSM)
                    .background(
                        color = ChatColors.TextSecondary.copy(alpha = 0.1f),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = if (typingUsers.isNotEmpty()) {
                        typingUsers.first().first().toString().uppercase()
                    } else "?",
                    style = ChatTextStyles.TimestampText.copy(
                        color = ChatColors.TextSecondary
                    )
                )
            }
            
            Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
            
            // Typing bubble
            Surface(
                color = ChatColors.OtherMessage,
                shape = RoundedCornerShape(ChatDimensions.RadiusLG),
                shadowElevation = ChatShadows.Card
            ) {
                Row(
                    modifier = Modifier.padding(
                        horizontal = ChatDimensions.PaddingMD,
                        vertical = ChatDimensions.PaddingSM
                    ),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Animated dots
                    dots.forEach { dot ->
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .background(
                                    color = ChatColors.TextSecondary.copy(
                                        alpha = dot.value
                                    ),
                                    shape = CircleShape
                                )
                        )
                        
                        Spacer(modifier = Modifier.width(4.dp))
                    }
                    
                    Text(
                        text = "입력 중...",
                        style = ChatTextStyles.SystemText.copy(
                            fontSize = 12.sp
                        )
                    )
                }
            }
        }
    }
}