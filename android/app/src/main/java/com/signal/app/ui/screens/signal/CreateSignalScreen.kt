package com.signal.app.ui.screens.signal

import androidx.compose.animation.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import com.signal.app.features.signal.data.models.SignalCategory
import com.signal.app.features.signal.presentation.viewmodels.SignalCreateViewModel
import com.signal.app.features.signal.presentation.viewmodels.SignalCreateStatus
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateSignalScreen(
    navController: NavController,
    viewModel: SignalCreateViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val hapticFeedback = LocalHapticFeedback.current

    LaunchedEffect(uiState.status) {
        when (uiState.status) {
            SignalCreateStatus.SUCCESS -> {
                hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                navController.navigateUp()
            }
            SignalCreateStatus.FAILURE -> {
                hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            else -> {}
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        "시그널 만들기",
                        fontWeight = FontWeight.SemiBold
                    ) 
                },
                navigationIcon = {
                    IconButton(onClick = { navController.navigateUp() }) {
                        Icon(Icons.Default.Close, contentDescription = "닫기")
                    }
                },
                actions = {
                    TextButton(
                        onClick = {
                            if (viewModel.isLastStep()) {
                                viewModel.createSignal()
                            } else {
                                val nextStep = uiState.currentStep + 1
                                if (nextStep < uiState.totalSteps) {
                                    viewModel.setCurrentStep(nextStep)
                                }
                            }
                        },
                        enabled = uiState.isValid && uiState.status != SignalCreateStatus.LOADING
                    ) {
                        Text(
                            if (viewModel.isLastStep()) "완료" else "다음",
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Progress Indicator
            ProgressIndicator(
                currentStep = uiState.currentStep,
                totalSteps = uiState.totalSteps,
                stepValidation = uiState.stepValidation,
                getStepTitle = viewModel::getStepTitle
            )

            // Step Content
            AnimatedContent(
                targetState = uiState.currentStep,
                transitionSpec = {
                    slideInHorizontally { width -> width } + fadeIn() togetherWith
                    slideOutHorizontally { width -> -width } + fadeOut()
                },
                label = "step_content"
            ) { step ->
                when (step) {
                    0 -> CategoryStep(
                        selectedCategory = uiState.selectedCategory,
                        onCategorySelected = { category ->
                            viewModel.selectCategory(category)
                            hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        }
                    )
                    1 -> BasicInfoStep(
                        title = uiState.title,
                        description = uiState.description,
                        scheduledDateTime = uiState.scheduledDateTime,
                        maxParticipants = uiState.maxParticipants,
                        onInfoChanged = { title, description, dateTime, participants ->
                            viewModel.updateBasicInfo(title, description, dateTime, participants)
                        }
                    )
                    2 -> LocationStep(
                        latitude = uiState.latitude,
                        longitude = uiState.longitude,
                        address = uiState.address,
                        placeName = uiState.placeName,
                        onLocationSelected = { lat, lon, addr, place ->
                            viewModel.updateLocation(lat, lon, addr, place)
                        }
                    )
                    3 -> SettingsStep(
                        minAge = uiState.minAge,
                        maxAge = uiState.maxAge,
                        genderPreference = uiState.genderPreference,
                        allowInstantJoin = uiState.allowInstantJoin,
                        requireApproval = uiState.requireApproval,
                        onSettingsChanged = { minAge, maxAge, gender, instant, approval ->
                            viewModel.updateSettings(minAge, maxAge, gender, instant, approval)
                        }
                    )
                }
            }

            // Bottom Actions
            BottomActions(
                currentStep = uiState.currentStep,
                totalSteps = uiState.totalSteps,
                canProceed = uiState.isValid,
                isLoading = uiState.status == SignalCreateStatus.LOADING,
                onPrevious = {
                    if (uiState.currentStep > 0) {
                        viewModel.setCurrentStep(uiState.currentStep - 1)
                    }
                },
                onNext = {
                    if (viewModel.isLastStep()) {
                        viewModel.createSignal()
                    } else {
                        val nextStep = uiState.currentStep + 1
                        if (nextStep < uiState.totalSteps) {
                            viewModel.setCurrentStep(nextStep)
                        }
                    }
                }
            )
        }
    }

    // Error Snackbar
    uiState.error?.let { error ->
        LaunchedEffect(error) {
            // Show snackbar - this would typically be handled by a SnackbarHost
            viewModel.clearError()
        }
    }
}

@Composable
private fun ProgressIndicator(
    currentStep: Int,
    totalSteps: Int,
    stepValidation: Map<Int, Boolean>,
    getStepTitle: (Int) -> String
) {
    Column(
        modifier = Modifier.padding(20.dp)
    ) {
        // Step indicators
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(totalSteps) { index ->
                val isActive = index == currentStep
                val isCompleted = index < currentStep
                val isValid = stepValidation[index] ?: false

                Box(
                    modifier = Modifier.weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Surface(
                        modifier = Modifier.size(32.dp),
                        shape = CircleShape,
                        color = when {
                            isCompleted || (isActive && isValid) -> MaterialTheme.colorScheme.primary
                            isActive -> MaterialTheme.colorScheme.primaryContainer
                            else -> MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)
                        },
                        border = if (isActive && !isCompleted) {
                            BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
                        } else null
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            if (isCompleted) {
                                Icon(
                                    Icons.Default.Check,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onPrimary,
                                    modifier = Modifier.size(18.dp)
                                )
                            } else {
                                Text(
                                    text = (index + 1).toString(),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = when {
                                        isActive -> MaterialTheme.colorScheme.onPrimaryContainer
                                        else -> MaterialTheme.colorScheme.onSurfaceVariant
                                    },
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Step title and progress
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = getStepTitle(currentStep),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary
            )
            Text(
                text = "${currentStep + 1} / $totalSteps",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun CategoryStep(
    selectedCategory: SignalCategory?,
    onCategorySelected: (SignalCategory) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp)
            .verticalScroll(rememberScrollState())
    ) {
        StepHeader(
            title = "무엇을 함께 할까요?",
            subtitle = "관심사를 선택하면 비슷한 취향의 사람들과 연결됩니다",
            icon = Icons.Default.Interests
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Category Grid
        val categories = SignalCategory.entries.filter { it != SignalCategory.OTHER }
        val chunkedCategories = categories.chunked(2)

        chunkedCategories.forEach { rowCategories ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                rowCategories.forEach { category ->
                    CategoryCard(
                        category = category,
                        isSelected = selectedCategory == category,
                        onClick = { onCategorySelected(category) },
                        modifier = Modifier.weight(1f)
                    )
                }
                // Fill remaining space if odd number
                if (rowCategories.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }
    }
}

@Composable
private fun CategoryCard(
    category: SignalCategory,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        onClick = onClick,
        modifier = modifier.aspectRatio(1f),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) {
                MaterialTheme.colorScheme.primaryContainer
            } else {
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
            }
        ),
        border = if (isSelected) {
            BorderStroke(2.dp, MaterialTheme.colorScheme.primary)
        } else null
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Icon would go here - using a simple circle for now
            Surface(
                modifier = Modifier.size(40.dp),
                shape = CircleShape,
                color = if (isSelected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)
                }
            ) {}
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = category.displayName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) {
                    MaterialTheme.colorScheme.onPrimaryContainer
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
        }
    }
}

@Composable
private fun BasicInfoStep(
    title: String,
    description: String,
    scheduledDateTime: LocalDateTime?,
    maxParticipants: Int,
    onInfoChanged: (String, String, LocalDateTime?, Int) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp)
            .verticalScroll(rememberScrollState())
    ) {
        StepHeader(
            title = "시그널 상세 정보",
            subtitle = "멋진 제목과 설명으로 사람들의 관심을 끌어보세요",
            icon = Icons.Default.EditNote
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Title Input
        OutlinedTextField(
            value = title,
            onValueChange = { newTitle ->
                onInfoChanged(newTitle, description, scheduledDateTime, maxParticipants)
            },
            label = { Text("제목") },
            placeholder = { Text("예: 한강에서 함께 피크닉 해요! 🧺") },
            modifier = Modifier.fillMaxWidth(),
            isError = title.trim().length < 5 && title.isNotEmpty(),
            supportingText = if (title.trim().length < 5 && title.isNotEmpty()) {
                { Text("제목은 5자 이상 입력해주세요") }
            } else null
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Description Input
        OutlinedTextField(
            value = description,
            onValueChange = { newDescription ->
                onInfoChanged(title, newDescription, scheduledDateTime, maxParticipants)
            },
            label = { Text("설명 (선택사항)") },
            placeholder = { Text("활동에 대한 상세한 설명을 적어주세요") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
            maxLines = 4
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Date Time - Simplified for now
        Card(
            onClick = { 
                // TODO: Show date time picker
                val now = LocalDateTime.now().plusHours(1)
                onInfoChanged(title, description, now, maxParticipants)
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Default.Schedule, contentDescription = null)
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = scheduledDateTime?.format(DateTimeFormatter.ofPattern("M월 d일 HH:mm")) 
                        ?: "날짜와 시간을 선택하세요",
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Participant Counter
        Card(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("참여 인원", style = MaterialTheme.typography.titleMedium)
                
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = { 
                            if (maxParticipants > 2) {
                                onInfoChanged(title, description, scheduledDateTime, maxParticipants - 1)
                            }
                        },
                        enabled = maxParticipants > 2
                    ) {
                        Icon(Icons.Default.Remove, contentDescription = "감소")
                    }
                    
                    Text(
                        text = "${maxParticipants}명",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 16.dp)
                    )
                    
                    IconButton(
                        onClick = { 
                            if (maxParticipants < 20) {
                                onInfoChanged(title, description, scheduledDateTime, maxParticipants + 1)
                            }
                        },
                        enabled = maxParticipants < 20
                    ) {
                        Icon(Icons.Default.Add, contentDescription = "증가")
                    }
                }
            }
        }
    }
}

@Composable
private fun LocationStep(
    latitude: Double?,
    longitude: Double?,
    address: String?,
    placeName: String?,
    onLocationSelected: (Double, Double, String, String?) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize()
    ) {
        Box(
            modifier = Modifier.padding(20.dp)
        ) {
            StepHeader(
                title = "어디서 만날까요?",
                subtitle = "지도를 터치해서 만날 장소를 선택해주세요",
                icon = Icons.Default.Place
            )
        }

        // TODO: Implement Google Maps integration
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            contentAlignment = Alignment.Center
        ) {
            Card(
                onClick = {
                    // Mock location selection for now
                    onLocationSelected(37.5665, 126.9780, "서울특별시 중구", "서울시청")
                },
                modifier = Modifier.fillMaxSize()
            ) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(
                        Icons.Default.Map,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = address ?: "지도에서 위치를 선택하세요",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    if (placeName != null) {
                        Text(
                            text = placeName,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsStep(
    minAge: Int?,
    maxAge: Int?,
    genderPreference: String,
    allowInstantJoin: Boolean,
    requireApproval: Boolean,
    onSettingsChanged: (Int?, Int?, String, Boolean, Boolean) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp)
            .verticalScroll(rememberScrollState())
    ) {
        StepHeader(
            title = "참여 설정",
            subtitle = "누가 참여할 수 있는지 설정해주세요",
            icon = Icons.Default.Settings
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Age Range - Simplified
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("연령대", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(8.dp))
                Text("전체 연령", style = MaterialTheme.typography.bodyMedium)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Gender Preference
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("성별 선호", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(12.dp))
                
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        "any" to "성별 무관",
                        "male" to "남성만",
                        "female" to "여성만"
                    ).forEach { (value, label) ->
                        FilterChip(
                            onClick = {
                                onSettingsChanged(minAge, maxAge, value, allowInstantJoin, requireApproval)
                            },
                            label = { Text(label) },
                            selected = genderPreference == value
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Join Settings
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("참가 방식", style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(12.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("즉시 참가 허용")
                    Switch(
                        checked = allowInstantJoin,
                        onCheckedChange = { instant ->
                            onSettingsChanged(
                                minAge, maxAge, genderPreference, 
                                instant, if (instant) false else requireApproval
                            )
                        }
                    )
                }
                
                if (!allowInstantJoin) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("참가 승인 필요")
                        Switch(
                            checked = requireApproval,
                            onCheckedChange = { approval ->
                                onSettingsChanged(minAge, maxAge, genderPreference, allowInstantJoin, approval)
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StepHeader(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Surface(
            modifier = Modifier.size(48.dp),
            shape = CircleShape,
            color = MaterialTheme.colorScheme.primaryContainer
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun BottomActions(
    currentStep: Int,
    totalSteps: Int,
    canProceed: Boolean,
    isLoading: Boolean,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        tonalElevation = 4.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (currentStep > 0) {
                OutlinedButton(
                    onClick = onPrevious,
                    modifier = Modifier.weight(1f)
                ) {
                    Text("이전")
                }
            }
            
            Button(
                onClick = onNext,
                enabled = canProceed && !isLoading,
                modifier = Modifier.weight(if (currentStep > 0) 2f else 1f)
            ) {
                if (isLoading) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                        Text("생성 중...")
                    }
                } else {
                    Text(
                        if (currentStep == totalSteps - 1) "시그널 생성" else "다음",
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}