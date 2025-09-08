package com.signal.app.features.auth.presentation.composables

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.signal.app.features.auth.presentation.viewmodels.MagicLinkViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MagicLinkScreen(
    onAuthSuccess: (String, Boolean) -> Unit,
    onAuthError: (String) -> Unit,
    magicLinkViewModel: MagicLinkViewModel = hiltViewModel()
) {
    val uiState by magicLinkViewModel.uiState.collectAsState()
    val keyboardController = LocalSoftwareKeyboardController.current

    // Animation for screen entrance
    val animatedVisibilityState = remember {
        MutableTransitionState(false).apply {
            targetState = true
        }
    }

    LaunchedEffect(Unit) {
        magicLinkViewModel.setCallbacks(onAuthSuccess, onAuthError)
    }

    AnimatedVisibility(
        visibleState = animatedVisibilityState,
        enter = fadeIn(animationSpec = tween(800)) + slideInVertically(
            initialOffsetY = { it / 3 },
            animationSpec = tween(600)
        )
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
                MagicLinkHeader(uiState.emailSent)
                Spacer(modifier = Modifier.height(48.dp))
                
                AnimatedContent(
                    targetState = uiState.emailSent,
                    transitionSpec = {
                        slideInHorizontally(
                            initialOffsetX = { if (targetState) it else -it },
                            animationSpec = tween(600)
                        ) togetherWith slideOutHorizontally(
                            targetOffsetX = { if (targetState) -it else it },
                            animationSpec = tween(600)
                        )
                    },
                    label = "content_animation"
                ) { emailSent ->
                    if (emailSent) {
                        SuccessView(
                            email = uiState.email,
                            onTryAnotherEmail = {
                                magicLinkViewModel.resetForm()
                            }
                        )
                    } else {
                        LoginForm(
                            email = uiState.email,
                            onEmailChange = { magicLinkViewModel.updateEmail(it) },
                            errorMessage = uiState.errorMessage,
                            isLoading = uiState.isLoading,
                            onSendMagicLink = {
                                keyboardController?.hide()
                                magicLinkViewModel.sendMagicLink()
                            }
                        )
                    }
                }
            }

            Footer()
        }
    }
}

@Composable
private fun MagicLinkHeader(emailSent: Boolean) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Animated icon container
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Card(
                modifier = Modifier.fillMaxSize(),
                colors = CardDefaults.cardColors(
                    containerColor = Color.Transparent
                ),
                elevation = CardDefaults.cardElevation(0.dp)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    // Gradient background
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(CircleShape)
                    ) {
                        // Use MaterialTheme colors for gradient
                        val primaryColor = MaterialTheme.colorScheme.primary
                        val primaryVariant = MaterialTheme.colorScheme.primaryContainer
                        
                        Surface(
                            modifier = Modifier.fillMaxSize(),
                            color = primaryColor,
                            shape = CircleShape
                        ) {
                            Icon(
                                imageVector = Icons.Outlined.Email,
                                contentDescription = "Mail Icon",
                                tint = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(20.dp)
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "🚀 Signal",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = if (emailSent) "이메일을 확인해주세요!" else "로그인하고 새로운 만남을 시작하세요",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LoginForm(
    email: String,
    onEmailChange: (String) -> Unit,
    errorMessage: String?,
    isLoading: Boolean,
    onSendMagicLink: () -> Unit
) {
    Column {
        OutlinedTextField(
            value = email,
            onValueChange = onEmailChange,
            label = { Text("이메일 주소를 입력하세요") },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Outlined.Email,
                    contentDescription = "Email Icon"
                )
            },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            keyboardActions = KeyboardActions(
                onDone = { onSendMagicLink() }
            ),
            singleLine = true,
            isError = errorMessage != null,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp)
        )

        errorMessage?.let { error ->
            Spacer(modifier = Modifier.height(12.dp))
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                ),
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.ErrorOutline,
                        contentDescription = "Error",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = error,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = onSendMagicLink,
            enabled = !isLoading && email.isNotEmpty(),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(16.dp)
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = MaterialTheme.colorScheme.onPrimary,
                    strokeWidth = 2.dp
                )
            } else {
                Text(
                    text = "로그인 링크 받기",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        InfoCard()
    }
}

@Composable
private fun SuccessView(
    email: String,
    onTryAnotherEmail: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Success icon
        Box(
            modifier = Modifier
                .size(100.dp)
                .clip(CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant,
                shape = CircleShape,
                modifier = Modifier.fillMaxSize()
            ) {
                Icon(
                    imageVector = Icons.Default.MarkEmailRead,
                    contentDescription = "Email sent",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(25.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "이메일을 보냈습니다!",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "${email}로\n로그인 링크를 보냈습니다.",
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(32.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "Info",
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "다음 단계",
                        fontWeight = FontWeight.SemiBold,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "1. 이메일 앱을 열어주세요\n2. Signal에서 보낸 이메일을 찾으세요\n3. \"로그인하기\" 버튼을 탭하세요",
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        TextButton(
            onClick = onTryAnotherEmail
        ) {
            Text("다른 이메일로 시도하기")
        }
    }
}

@Composable
private fun InfoCard() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Outlined.Security,
                    contentDescription = "Security",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "안전한 로그인",
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "비밀번호 없이 이메일 링크로 안전하게 로그인하세요.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
private fun Footer() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "로그인하면 Signal의 서비스 약관 및 개인정보 처리방침에 동의하게 됩니다.",
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(8.dp))

        Row(
            horizontalArrangement = Arrangement.Center
        ) {
            TextButton(
                onClick = { /* Navigate to terms */ }
            ) {
                Text(
                    text = "서비스 약관",
                    style = MaterialTheme.typography.bodySmall
                )
            }
            Text(
                text = "•",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 4.dp)
            )
            TextButton(
                onClick = { /* Navigate to privacy policy */ }
            ) {
                Text(
                    text = "개인정보 처리방침",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}