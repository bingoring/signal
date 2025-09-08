package com.signal.app.features.signal.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.signal.app.features.signal.data.models.Signal
import com.signal.app.features.signal.data.models.SignalCategory
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * 시그널 상세 정보 바텀시트
 * Flutter SignalBottomSheet와 동일한 기능을 Android에서 제공
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignalBottomSheet(
    signal: Signal,
    onJoinSignal: (Int, String?) -> Unit,
    onLeaveSignal: (Int) -> Unit,
    onDismiss: () -> Unit
) {
    var showJoinDialog by remember { mutableStateOf(false) }
    var joinMessage by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        dragHandle = {
            Surface(
                modifier = Modifier
                    .width(32.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
            ) {}
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 헤더 섹션
            SignalHeader(signal = signal)

            // 정보 섹션
            SignalInfo(signal = signal)

            // 액션 버튼 섹션
            SignalActionButtons(
                signal = signal,
                onJoinClick = { showJoinDialog = true },
                onLeaveClick = { onLeaveSignal(signal.id) }
            )
        }
    }

    // 참여 확인 다이얼로그
    if (showJoinDialog) {
        JoinSignalDialog(
            signal = signal,
            message = joinMessage,
            onMessageChange = { joinMessage = it },
            onConfirm = {
                onJoinSignal(signal.id, joinMessage.takeIf { it.isNotBlank() })
                showJoinDialog = false
                joinMessage = ""
            },
            onDismiss = { 
                showJoinDialog = false
                joinMessage = ""
            }
        )
    }
}

@Composable
private fun SignalHeader(signal: Signal) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        // 카테고리 아이콘
        Surface(
            modifier = Modifier.size(48.dp),
            shape = RoundedCornerShape(12.dp),
            color = getCategoryColor(signal.category)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = getCategoryIcon(signal.category),
                    contentDescription = signal.category,
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.onPrimary
                )
            }
        }

        Column(modifier = Modifier.weight(1f)) {
            // 제목
            Text(
                text = signal.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            // 생성자 및 시간
            Text(
                text = "by ${signal.creatorName}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // 상태 표시
            SignalStatusChip(signal = signal)
        }
    }
}

@Composable
private fun SignalInfo(signal: Signal) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // 설명
        if (signal.description.isNotBlank()) {
            Text(
                text = signal.description,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        // 위치 정보
        InfoRow(
            icon = Icons.Default.LocationOn,
            title = "위치",
            content = signal.address
        )

        // 참여자 정보
        InfoRow(
            icon = Icons.Default.Group,
            title = "참여자",
            content = "${signal.currentParticipants} / ${signal.maxParticipants}명"
        )

        // 예약 시간 (있는 경우)
        if (signal.hasScheduledTime()) {
            val scheduledTime = try {
                LocalDateTime.parse(signal.scheduledTime, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                    .format(DateTimeFormatter.ofPattern("yyyy년 MM월 dd일 HH:mm"))
            } catch (e: Exception) {
                signal.scheduledTime
            }

            InfoRow(
                icon = Icons.Default.Schedule,
                title = "예약 시간",
                content = scheduledTime ?: ""
            )
        }

        // 태그들
        if (signal.tags.isNotEmpty()) {
            TagSection(tags = signal.tags)
        }
    }
}

@Composable
private fun SignalActionButtons(
    signal: Signal,
    onJoinClick: () -> Unit,
    onLeaveClick: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        when {
            signal.canJoin() -> {
                Button(
                    onClick = onJoinClick,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary
                    )
                ) {
                    Icon(Icons.Default.Add, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("참여하기", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                }
            }
            signal.isActive() && signal.currentParticipants >= signal.maxParticipants -> {
                Button(
                    onClick = { },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = false,
                    colors = ButtonDefaults.buttonColors(
                        disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Icon(Icons.Default.Block, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("정원 초과", fontSize = 16.sp)
                }
            }
            else -> {
                OutlinedButton(
                    onClick = onLeaveClick,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Default.ExitToApp, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("나가기", fontSize = 16.sp)
                }
            }
        }
    }
}

@Composable
private fun InfoRow(
    icon: ImageVector,
    title: String,
    content: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Icon(
            imageVector = icon,
            contentDescription = title,
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = content,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun SignalStatusChip(signal: Signal) {
    val (statusText, statusColor) = when {
        signal.isActive() -> "활성" to MaterialTheme.colorScheme.primary
        signal.isCompleted() -> "완료" to MaterialTheme.colorScheme.outline
        signal.isExpired() -> "만료" to MaterialTheme.colorScheme.error
        else -> "비활성" to MaterialTheme.colorScheme.outline
    }

    Surface(
        modifier = Modifier,
        shape = RoundedCornerShape(8.dp),
        color = statusColor.copy(alpha = 0.1f)
    ) {
        Text(
            text = statusText,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = statusColor,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun TagSection(tags: List<String>) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "태그",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            tags.take(3).forEach { tag ->
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.secondaryContainer
                ) {
                    Text(
                        text = "#$tag",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer
                    )
                }
            }
            
            if (tags.size > 3) {
                Text(
                    text = "+${tags.size - 3}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun JoinSignalDialog(
    signal: Signal,
    message: String,
    onMessageChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("시그널 참여") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("'${signal.title}' 시그널에 참여하시겠습니까?")
                
                OutlinedTextField(
                    value = message,
                    onValueChange = onMessageChange,
                    label = { Text("참여 메시지 (선택사항)") },
                    placeholder = { Text("간단한 인사말을 남겨보세요") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text("참여하기")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("취소")
            }
        }
    )
}

// Helper functions
@Composable
private fun getCategoryColor(category: String): androidx.compose.ui.graphics.Color {
    return when (SignalCategory.fromString(category)) {
        SignalCategory.FOOD -> MaterialTheme.colorScheme.primary
        SignalCategory.COFFEE -> MaterialTheme.colorScheme.secondary
        SignalCategory.CULTURE -> MaterialTheme.colorScheme.tertiary
        SignalCategory.SPORTS -> MaterialTheme.colorScheme.primary
        SignalCategory.STUDY -> MaterialTheme.colorScheme.secondary
        SignalCategory.WORK -> MaterialTheme.colorScheme.tertiary
        SignalCategory.SOCIAL -> MaterialTheme.colorScheme.primary
        SignalCategory.TRAVEL -> MaterialTheme.colorScheme.secondary
        SignalCategory.SHOPPING -> MaterialTheme.colorScheme.tertiary
        SignalCategory.OTHER -> MaterialTheme.colorScheme.outline
    }
}

private fun getCategoryIcon(category: String): ImageVector {
    return when (SignalCategory.fromString(category)) {
        SignalCategory.FOOD -> Icons.Default.Restaurant
        SignalCategory.COFFEE -> Icons.Default.LocalCafe
        SignalCategory.CULTURE -> Icons.Default.Theater
        SignalCategory.SPORTS -> Icons.Default.SportsBaseball
        SignalCategory.STUDY -> Icons.Default.School
        SignalCategory.WORK -> Icons.Default.Work
        SignalCategory.SOCIAL -> Icons.Default.Group
        SignalCategory.TRAVEL -> Icons.Default.Flight
        SignalCategory.SHOPPING -> Icons.Default.ShoppingCart
        SignalCategory.OTHER -> Icons.Default.MoreHoriz
    }
}