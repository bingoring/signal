package com.signal.app.ui.screens.chat.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import coil.compose.AsyncImage
import com.signal.app.data.model.chat.SignalStatus
import com.signal.app.ui.theme.ChatColors
import com.signal.app.ui.theme.ChatDimensions
import com.signal.app.ui.theme.ChatShadows
import com.signal.app.ui.theme.ChatTextStyles

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InstagramStyleAppBar(
    signalTitle: String,
    participantAvatars: List<String>,
    status: SignalStatus,
    onlineCount: Int = 0,
    onBackPressed: () -> Unit = {},
    onInfoPressed: (() -> Unit)? = null,
    onMenuPressed: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    TopAppBar(
        title = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                // Participant profiles
                ParticipantProfiles(
                    avatars = participantAvatars,
                    modifier = Modifier.padding(end = ChatDimensions.PaddingMD)
                )
                
                // Title and status
                Column(
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        text = signalTitle,
                        style = ChatTextStyles.AppBarTitle,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 2.dp)
                    ) {
                        // Status indicator
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .scale(
                                    if (status == SignalStatus.MEETING) pulseScale else 1f
                                )
                                .background(
                                    color = getStatusColor(status),
                                    shape = CircleShape
                                )
                        )
                        
                        Spacer(modifier = Modifier.width(ChatDimensions.PaddingSM))
                        
                        Text(
                            text = getStatusText(status),
                            style = ChatTextStyles.AppBarSubtitle.copy(
                                color = getStatusColor(status)
                            )
                        )
                        
                        if (onlineCount > 0) {
                            Text(
                                text = " • ${onlineCount}명 온라인",
                                style = ChatTextStyles.AppBarSubtitle
                            )
                        }
                    }
                }
            }
        },
        navigationIcon = {
            IconButton(onClick = onBackPressed) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = "뒤로가기",
                    tint = ChatColors.TextPrimary
                )
            }
        },
        actions = {
            onInfoPressed?.let {
                IconButton(onClick = it) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "정보",
                        tint = ChatColors.TextSecondary
                    )
                }
            }
            
            onMenuPressed?.let {
                IconButton(onClick = it) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "메뉴",
                        tint = ChatColors.TextSecondary
                    )
                }
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = ChatColors.Surface
        ),
        modifier = modifier.shadow(
            elevation = ChatShadows.Card,
            spotColor = ChatShadows.SoftColor
        )
    )
}

@Composable
private fun ParticipantProfiles(
    avatars: List<String>,
    modifier: Modifier = Modifier
) {
    val maxVisible = 4
    val visibleAvatars = avatars.take(maxVisible)
    val remainingCount = avatars.size - maxVisible

    Box(
        modifier = modifier.height(ChatDimensions.AvatarMD)
    ) {
        visibleAvatars.forEachIndexed { index, avatarUrl ->
            ProfileAvatar(
                avatarUrl = avatarUrl,
                modifier = Modifier
                    .offset(x = (index * 20).dp)
                    .zIndex((maxVisible - index).toFloat())
            )
        }
        
        if (remainingCount > 0) {
            RemainingCountAvatar(
                count = remainingCount,
                modifier = Modifier
                    .offset(x = (visibleAvatars.size * 20).dp)
                    .zIndex(0f)
            )
        }
    }
}

@Composable
private fun ProfileAvatar(
    avatarUrl: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(ChatDimensions.AvatarMD)
            .border(
                width = 2.dp,
                color = ChatColors.Surface,
                shape = CircleShape
            )
            .shadow(
                elevation = ChatShadows.Card,
                shape = CircleShape,
                spotColor = ChatShadows.SoftColor
            )
    ) {
        if (avatarUrl.isNotEmpty()) {
            AsyncImage(
                model = avatarUrl,
                contentDescription = "프로필 이미지",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(CircleShape)
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        color = ChatColors.Primary.copy(alpha = 0.1f),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    painter = painterResource(android.R.drawable.ic_menu_my_calendar),
                    contentDescription = null,
                    tint = ChatColors.Primary,
                    modifier = Modifier.size((ChatDimensions.AvatarMD / 2))
                )
            }
        }
    }
}

@Composable
private fun RemainingCountAvatar(
    count: Int,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .size(ChatDimensions.AvatarMD)
            .background(
                color = ChatColors.TextSecondary,
                shape = CircleShape
            )
            .border(
                width = 2.dp,
                color = ChatColors.Surface,
                shape = CircleShape
            )
            .shadow(
                elevation = ChatShadows.Card,
                shape = CircleShape,
                spotColor = ChatShadows.SoftColor
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "+$count",
            color = ChatColors.TextOnPrimary,
            fontSize = 11.sp,
            style = ChatTextStyles.QuickReplyText
        )
    }
}

private fun getStatusColor(status: SignalStatus): Color {
    return when (status) {
        SignalStatus.ACTIVE -> ChatColors.Online
        SignalStatus.MEETING -> ChatColors.Accent
        SignalStatus.COMPLETED -> ChatColors.Primary
        SignalStatus.EXPIRED, SignalStatus.CLOSED -> ChatColors.Offline
    }
}

private fun getStatusText(status: SignalStatus): String {
    return when (status) {
        SignalStatus.ACTIVE -> "활성 중"
        SignalStatus.MEETING -> "모임 진행 중"
        SignalStatus.COMPLETED -> "모임 완료"
        SignalStatus.EXPIRED -> "만료됨"
        SignalStatus.CLOSED -> "종료됨"
    }
}