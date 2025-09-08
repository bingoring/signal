package com.signal.app.features.auth.presentation.composables

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun WelcomeScreen(
    onContinueToApp: () -> Unit
) {
    // Animation controllers
    val fadeAnimationState = remember { MutableTransitionState(false) }
    val scaleAnimationState = remember { MutableTransitionState(false) }

    LaunchedEffect(Unit) {
        fadeAnimationState.targetState = true
        kotlinx.coroutines.delay(200)
        scaleAnimationState.targetState = true
    }

    AnimatedVisibility(
        visibleState = fadeAnimationState,
        enter = fadeIn(animationSpec = tween(1000))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Spacer(modifier = Modifier.height(32.dp))

            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                AnimatedVisibility(
                    visibleState = scaleAnimationState,
                    enter = scaleIn(
                        animationSpec = spring(
                            dampingRatio = Spring.DampingRatioMediumBouncy,
                            stiffness = Spring.StiffnessLow
                        )
                    )
                ) {
                    WelcomeHeader()
                }

                Spacer(modifier = Modifier.height(48.dp))

                FeaturesList()
            }

            ContinueButton(onContinueToApp)
        }
    }
}

@Composable
private fun WelcomeHeader() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Animated celebration icon
        Box(
            modifier = Modifier
                .size(120.dp)
                .clip(CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                modifier = Modifier.fillMaxSize(),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primary,
                shadowElevation = 15.dp
            ) {
                Icon(
                    imageVector = Icons.Default.Celebration,
                    contentDescription = "Celebration",
                    tint = MaterialTheme.colorScheme.onPrimary,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(30.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = "🎉 환영합니다!",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Signal 가족이 되신 것을 축하합니다!\n새로운 만남과 경험이 기다리고 있어요",
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            lineHeight = MaterialTheme.typography.bodyLarge.lineHeight * 1.5f
        )
    }
}

@Composable
private fun FeaturesList() {
    val features = remember {
        listOf(
            FeatureItem(
                icon = Icons.Default.LocationOn,
                title = "실시간 시그널 탐색",
                description = "내 주변에서 일어나는 다양한 활동을 실시간으로 확인하세요",
                color = Color(0xFF2196F3) // Blue
            ),
            FeatureItem(
                icon = Icons.Default.People,
                title = "새로운 사람들과 만남",
                description = "관심사가 같은 사람들과 함께 활동하고 친구가 되어보세요",
                color = Color(0xFF4CAF50) // Green
            ),
            FeatureItem(
                icon = Icons.Default.ChatBubble,
                title = "실시간 채팅",
                description = "참여한 활동에서 다른 참가자들과 실시간으로 소통하세요",
                color = Color(0xFFFF9800) // Orange
            ),
            FeatureItem(
                icon = Icons.Default.AddCircle,
                title = "나만의 시그널 생성",
                description = "원하는 활동이 없다면 직접 시그널을 만들어보세요",
                color = Color(0xFF9C27B0) // Purple
            )
        )
    }

    Column {
        features.forEachIndexed { index, feature ->
            FeatureListItem(
                feature = feature,
                animationDelay = index * 100
            )
            if (index < features.size - 1) {
                Spacer(modifier = Modifier.height(20.dp))
            }
        }
    }
}

@Composable
private fun FeatureListItem(
    feature: FeatureItem,
    animationDelay: Int
) {
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(animationDelay.toLong())
        isVisible = true
    }

    AnimatedVisibility(
        visible = isVisible,
        enter = slideInHorizontally(
            initialOffsetX = { it / 2 },
            animationSpec = tween(600, easing = FastOutSlowInEasing)
        ) + fadeIn(animationSpec = tween(600))
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top
        ) {
            // Feature icon
            Box(
                modifier = Modifier
                    .size(50.dp)
                    .clip(CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    shape = CircleShape,
                    color = feature.color.copy(alpha = 0.1f)
                ) {
                    Icon(
                        imageVector = feature.icon,
                        contentDescription = feature.title,
                        tint = feature.color,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(13.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(16.dp))

            // Feature text
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = feature.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = feature.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    lineHeight = MaterialTheme.typography.bodyMedium.lineHeight * 1.4f
                )
            }
        }
    }
}

@Composable
private fun ContinueButton(onContinueToApp: () -> Unit) {
    Column {
        Button(
            onClick = onContinueToApp,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            )
        ) {
            Text(
                text = "Signal 시작하기",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "언제든지 설정에서 알림 및 개인정보 설정을 변경할 수 있습니다.",
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

private data class FeatureItem(
    val icon: ImageVector,
    val title: String,
    val description: String,
    val color: Color
)