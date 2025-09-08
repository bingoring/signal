package com.signal.app.features.auth.presentation.composables

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.signal.app.R
import com.signal.app.features.auth.presentation.viewmodels.AuthViewModel

@Composable
fun AuthWrapper(
    navigateToHome: () -> Unit,
    navigateToWelcome: () -> Unit,
    authViewModel: AuthViewModel = hiltViewModel()
) {
    val uiState by authViewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        authViewModel.initializeAuth()
    }

    LaunchedEffect(uiState.isAuthenticated, uiState.isNewUser) {
        if (uiState.isAuthenticated) {
            if (uiState.isNewUser) {
                navigateToWelcome()
            } else {
                navigateToHome()
            }
        }
    }

    if (uiState.isLoading) {
        LoadingScreen()
    } else if (!uiState.isAuthenticated) {
        MagicLinkScreen(
            onAuthSuccess = { token, isNewUser ->
                authViewModel.onAuthSuccess(token, isNewUser)
            },
            onAuthError = { error ->
                authViewModel.onAuthError(error)
            }
        )
    }

    uiState.errorMessage?.let { error ->
        LaunchedEffect(error) {
            // Show error snackbar or handle error
            authViewModel.clearError()
        }
    }
}

@Composable
private fun LoadingScreen() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            CircularProgressIndicator()
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Signal 로딩 중...",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}