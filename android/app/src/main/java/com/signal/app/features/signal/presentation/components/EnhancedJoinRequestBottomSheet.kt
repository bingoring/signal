package com.signal.app.features.signal.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.signal.app.features.signal.data.models.*
import com.signal.app.features.signal.presentation.viewmodels.JoinRequestViewModel
import com.signal.app.features.signal.presentation.viewmodels.JoinRequestStatus
import com.signal.app.features.signal.presentation.viewmodels.SubmitStatus
import com.signal.app.features.signal.presentation.viewmodels.ActionStatus
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Enhanced Join Request Bottom Sheet
 * iOS EnhancedJoinRequestBottomSheet와 동일한 기능을 Android에서 제공
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EnhancedJoinRequestBottomSheet(
    signal: Signal,
    isOwner: Boolean,
    currentUserId: Int?,
    onDismiss: () -> Unit,
    viewModel: JoinRequestViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val hapticFeedback = LocalHapticFeedback.current
    var selectedTab by remember { mutableIntStateOf(0) }
    var joinMessage by remember { mutableStateOf("") }

    // Load data when sheet opens
    LaunchedEffect(signal.id) {
        viewModel.loadJoinRequests(signal.id)
        if (currentUserId != null) {
            viewModel.loadMyJoinStatus(signal.id)
        }
    }

    // Handle state changes
    LaunchedEffect(uiState.submitStatus) {
        when (uiState.submitStatus) {
            SubmitStatus.SUBMITTED -> {
                hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                onDismiss()
            }
            SubmitStatus.FAILED -> {
                hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            else -> {}
        }
    }

    LaunchedEffect(uiState.actionStatus) {
        if (uiState.actionStatus == ActionStatus.SUCCESS) {
            hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        dragHandle = {
            Surface(
                modifier = Modifier
                    .width(40.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
            ) {}
        },
        windowInsets = WindowInsets(0)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 600.dp)
        ) {
            // Header
            BottomSheetHeader(
                signal = signal,
                isOwner = isOwner
            )

            if (isOwner) {
                // Owner interface with tabs
                OwnerTabInterface(
                    selectedTab = selectedTab,
                    onTabSelected = { selectedTab = it },
                    pendingCount = viewModel.pendingRequests.size,
                    approvedCount = viewModel.approvedRequests.size,
                    rejectedCount = viewModel.rejectedRequests.size
                )

                when (selectedTab) {
                    0 -> PendingRequestsList(
                        requests = viewModel.pendingRequests,
                        isLoading = uiState.status == JoinRequestStatus.LOADING,
                        onApprove = { request -> 
                            viewModel.approveJoinRequest(signal.id, request.userId, null)
                        },
                        onReject = { request, reason ->
                            viewModel.rejectJoinRequest(signal.id, request.userId, reason)
                        }
                    )
                    1 -> ApprovedRequestsList(
                        requests = viewModel.approvedRequests,
                        isLoading = uiState.status == JoinRequestStatus.LOADING
                    )
                    2 -> RejectedRequestsList(
                        requests = viewModel.rejectedRequests,
                        isLoading = uiState.status == JoinRequestStatus.LOADING
                    )
                }
            } else {
                // User interface
                val hasRequested = currentUserId?.let { viewModel.hasUserRequested(it) } ?: false
                val userRequest = currentUserId?.let { viewModel.getUserRequest(it) }

                if (hasRequested && userRequest != null) {
                    RequestStatusDisplay(request = userRequest)
                } else {
                    JoinRequestForm(
                        signal = signal,
                        message = joinMessage,
                        onMessageChange = { joinMessage = it },
                        isSubmitting = uiState.submitStatus == SubmitStatus.SUBMITTING,
                        onSubmit = {
                            viewModel.submitJoinRequest(
                                signal.id,
                                joinMessage.takeIf { it.isNotBlank() }
                            )
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun BottomSheetHeader(
    signal: Signal,
    isOwner: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Surface(
            modifier = Modifier.size(48.dp),
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.primaryContainer
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = if (isOwner) Icons.Default.Group else Icons.Default.PersonAdd,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = if (isOwner) "참가 신청서 관리" else "시그널 참가하기",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = signal.title,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun OwnerTabInterface(
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    pendingCount: Int,
    approvedCount: Int,
    rejectedCount: Int
) {
    TabRow(
        selectedTabIndex = selectedTab,
        modifier = Modifier.padding(horizontal = 20.dp),
        contentColor = MaterialTheme.colorScheme.primary
    ) {
        Tab(
            selected = selectedTab == 0,
            onClick = { onTabSelected(0) }
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("대기")
                if (pendingCount > 0) {
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = Color(0xFFFF9800)
                    ) {
                        Text(
                            text = pendingCount.toString(),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                }
            }
        }

        Tab(
            selected = selectedTab == 1,
            onClick = { onTabSelected(1) }
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("승인")
                if (approvedCount > 0) {
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = Color(0xFF4CAF50)
                    ) {
                        Text(
                            text = approvedCount.toString(),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                }
            }
        }

        Tab(
            selected = selectedTab == 2,
            onClick = { onTabSelected(2) }
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("거절")
                if (rejectedCount > 0) {
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = Color(0xFFF44336)
                    ) {
                        Text(
                            text = rejectedCount.toString(),
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PendingRequestsList(
    requests: List<SignalJoinRequest>,
    isLoading: Boolean,
    onApprove: (SignalJoinRequest) -> Unit,
    onReject: (SignalJoinRequest, String) -> Unit
) {
    if (isLoading) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator()
        }
    } else if (requests.isEmpty()) {
        EmptyState(
            message = "대기 중인 신청서가 없습니다",
            icon = Icons.Default.Inbox
        )
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(requests) { request ->
                JoinRequestCard(
                    request = request,
                    isPending = true,
                    onApprove = { onApprove(request) },
                    onReject = { reason -> onReject(request, reason) }
                )
            }
        }
    }
}

@Composable
private fun ApprovedRequestsList(
    requests: List<SignalJoinRequest>,
    isLoading: Boolean
) {
    if (isLoading) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator()
        }
    } else if (requests.isEmpty()) {
        EmptyState(
            message = "승인된 신청서가 없습니다",
            icon = Icons.Default.CheckCircleOutline
        )
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(requests) { request ->
                JoinRequestCard(
                    request = request,
                    isPending = false
                )
            }
        }
    }
}

@Composable
private fun RejectedRequestsList(
    requests: List<SignalJoinRequest>,
    isLoading: Boolean
) {
    if (isLoading) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator()
        }
    } else if (requests.isEmpty()) {
        EmptyState(
            message = "거절된 신청서가 없습니다",
            icon = Icons.Default.CancelOutlined
        )
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(requests) { request ->
                JoinRequestCard(
                    request = request,
                    isPending = false
                )
            }
        }
    }
}

@Composable
private fun JoinRequestCard(
    request: SignalJoinRequest,
    isPending: Boolean,
    onApprove: (() -> Unit)? = null,
    onReject: ((String) -> Unit)? = null
) {
    var showRejectDialog by remember { mutableStateOf(false) }
    var showApproveDialog by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // User info
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Avatar
                Surface(
                    modifier = Modifier.size(48.dp),
                    shape = RoundedCornerShape(24.dp),
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            text = request.user?.profile?.displayName?.firstOrNull()?.toString() ?: "U",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = request.user?.profile?.displayName ?: request.user?.username ?: "사용자",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    
                    request.user?.profile?.let { profile ->
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "${profile.age}세",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Surface(
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
                            ) {
                                Text(
                                    text = "매너점수 ${String.format("%.1f", profile.mannerScore)}",
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }

                // Status badge
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = getStatusColor(request.status).copy(alpha = 0.1f)
                ) {
                    Text(
                        text = getStatusText(request.status),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = getStatusColor(request.status),
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Message
            request.message?.let { message ->
                if (message.isNotBlank()) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                        )
                    ) {
                        Text(
                            text = message,
                            modifier = Modifier.padding(12.dp),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            // Actions for pending requests
            if (isPending && onApprove != null && onReject != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    OutlinedButton(
                        onClick = { showRejectDialog = true },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Color(0xFFF44336)
                        ),
                        border = ButtonDefaults.outlinedButtonBorder.copy(
                            brush = null,
                            width = 1.dp
                        )
                    ) {
                        Text("거절")
                    }

                    Button(
                        onClick = { showApproveDialog = true },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF4CAF50)
                        )
                    ) {
                        Text("승인")
                    }
                }
            }

            // Request time
            Text(
                text = "신청일시: ${formatDateTime(request.createdAt)}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }

    // Approve dialog
    if (showApproveDialog) {
        var approveMessage by remember { mutableStateOf("") }
        
        AlertDialog(
            onDismissRequest = { showApproveDialog = false },
            title = { Text("신청 승인") },
            text = {
                Column {
                    Text("${request.user?.profile?.displayName ?: "사용자"}님의 참가 신청을 승인하시겠습니까?")
                    Spacer(modifier = Modifier.height(16.dp))
                    OutlinedTextField(
                        value = approveMessage,
                        onValueChange = { approveMessage = it },
                        label = { Text("승인 메시지 (선택사항)") },
                        placeholder = { Text("환영합니다! 함께 즐거운 시간 보내요.") },
                        modifier = Modifier.fillMaxWidth(),
                        maxLines = 2
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        onApprove()
                        showApproveDialog = false
                    }
                ) {
                    Text("승인")
                }
            },
            dismissButton = {
                TextButton(onClick = { showApproveDialog = false }) {
                    Text("취소")
                }
            }
        )
    }

    // Reject dialog
    if (showRejectDialog) {
        var rejectReason by remember { mutableStateOf("") }
        
        AlertDialog(
            onDismissRequest = { showRejectDialog = false },
            title = { Text("신청 거절") },
            text = {
                Column {
                    Text("${request.user?.profile?.displayName ?: "사용자"}님의 참가 신청을 거절하는 이유를 알려주세요.")
                    Spacer(modifier = Modifier.height(16.dp))
                    OutlinedTextField(
                        value = rejectReason,
                        onValueChange = { rejectReason = it },
                        label = { Text("거절 이유 *") },
                        placeholder = { Text("정원 초과, 연령대 불일치 등") },
                        modifier = Modifier.fillMaxWidth(),
                        maxLines = 3,
                        isError = rejectReason.trim().isEmpty()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (rejectReason.trim().isNotEmpty()) {
                            onReject(rejectReason.trim())
                            showRejectDialog = false
                        }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFFF44336)
                    ),
                    enabled = rejectReason.trim().isNotEmpty()
                ) {
                    Text("거절")
                }
            },
            dismissButton = {
                TextButton(onClick = { showRejectDialog = false }) {
                    Text("취소")
                }
            }
        )
    }
}

@Composable
private fun RequestStatusDisplay(request: SignalJoinRequest) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = getStatusColor(request.status).copy(alpha = 0.1f)
            )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Icon(
                    imageVector = getStatusIcon(request.status),
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = getStatusColor(request.status)
                )

                Text(
                    text = getStatusTitle(request.status),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = getStatusColor(request.status)
                )

                Text(
                    text = getStatusMessage(request.status),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
            }
        }

        request.message?.takeIf { it.isNotBlank() }?.let { message ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    Text(
                        text = "전달한 메시지",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
    }
}

@Composable
private fun JoinRequestForm(
    signal: Signal,
    message: String,
    onMessageChange: (String) -> Unit,
    isSubmitting: Boolean,
    onSubmit: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        // Signal info
        SignalInfoCard(signal = signal)

        // Message input
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "간단한 인사말을 남겨보세요 (선택사항)",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            OutlinedTextField(
                value = message,
                onValueChange = onMessageChange,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("예: 안녕하세요! 함께 즐거운 시간 보내요 😊") },
                minLines = 3,
                maxLines = 3
            )
        }

        // Submit button
        Button(
            onClick = onSubmit,
            modifier = Modifier.fillMaxWidth(),
            enabled = !isSubmitting
        ) {
            if (isSubmitting) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Text("신청 중...")
                }
            } else {
                Text(
                    text = "참가 신청하기",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // Info card
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
            )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    Icons.Default.Info,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Column {
                    Text(
                        text = "참가 신청 안내",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = if (signal.requireApproval) {
                            "• 이 시그널은 승인이 필요합니다\n• 호스트가 승인하면 참가가 확정됩니다\n• 매너 있는 소통을 부탁드려요"
                        } else {
                            "• 즉시 참가가 가능한 시그널입니다\n• 신청과 함께 참가가 확정됩니다\n• 매너 있는 소통을 부탁드려요"
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun SignalInfoCard(signal: Signal) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.People,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "참여 인원: ${signal.currentParticipants}/${signal.maxParticipants}명",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = if (signal.requireApproval) Icons.Default.Approval else Icons.Default.FlashOn,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = if (signal.requireApproval) "승인 필요" else "즉시 참가",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun EmptyState(
    message: String,
    icon: ImageVector
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// Helper functions
private fun getStatusColor(status: String): Color {
    return when (status) {
        "pending" -> Color(0xFFFF9800)
        "approved" -> Color(0xFF4CAF50)
        "rejected" -> Color(0xFFF44336)
        "expired" -> Color(0xFF9E9E9E)
        else -> Color(0xFF9E9E9E)
    }
}

private fun getStatusIcon(status: String): ImageVector {
    return when (status) {
        "pending" -> Icons.Default.HourglassEmpty
        "approved" -> Icons.Default.CheckCircle
        "rejected" -> Icons.Default.Cancel
        "expired" -> Icons.Default.AccessTime
        else -> Icons.Default.Help
    }
}

private fun getStatusTitle(status: String): String {
    return when (status) {
        "pending" -> "승인 대기 중"
        "approved" -> "참가 승인됨!"
        "rejected" -> "참가 거절됨"
        "expired" -> "신청 만료됨"
        else -> "알 수 없음"
    }
}

private fun getStatusMessage(status: String): String {
    return when (status) {
        "pending" -> "호스트가 승인하면 참가가 확정됩니다.\n조금만 기다려주세요!"
        "approved" -> "축하합니다! 시그널 참가가 확정되었습니다.\n채팅방에서 다른 참가자들과 소통해보세요."
        "rejected" -> "아쉽지만 이번 시그널 참가가 거절되었습니다.\n다른 시그널을 찾아보시는 건 어떨까요?"
        "expired" -> "신청 기한이 만료되었습니다."
        else -> ""
    }
}

private fun getStatusText(status: String): String {
    return when (status) {
        "pending" -> "대기중"
        "approved" -> "승인됨"
        "rejected" -> "거절됨"
        "expired" -> "만료됨"
        else -> "알수없음"
    }
}

private fun formatDateTime(dateTimeString: String): String {
    return try {
        val dateTime = LocalDateTime.parse(dateTimeString, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        "${dateTime.monthValue}/${dateTime.dayOfMonth} ${dateTime.hour.toString().padStart(2, '0')}:${dateTime.minute.toString().padStart(2, '0')}"
    } catch (e: Exception) {
        dateTimeString
    }
}