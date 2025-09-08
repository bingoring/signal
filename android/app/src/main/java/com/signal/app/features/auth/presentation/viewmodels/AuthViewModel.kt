package com.signal.app.features.auth.presentation.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.core.services.DeepLinkService
import com.signal.app.features.auth.data.services.AuthService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = true,
    val isAuthenticated: Boolean = false,
    val isNewUser: Boolean = false,
    val errorMessage: String? = null
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authService: AuthService,
    private val deepLinkService: DeepLinkService
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        setupDeepLinkCallbacks()
    }

    fun initializeAuth() {
        viewModelScope.launch {
            try {
                val isAuthenticated = authService.isAuthenticated()
                _uiState.value = _uiState.value.copy(
                    isAuthenticated = isAuthenticated,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isAuthenticated = false,
                    isLoading = false,
                    errorMessage = e.message
                )
            }
        }
    }

    fun onAuthSuccess(token: String, isNewUser: Boolean) {
        _uiState.value = _uiState.value.copy(
            isAuthenticated = true,
            isNewUser = isNewUser,
            errorMessage = null
        )
    }

    fun onAuthError(error: String) {
        _uiState.value = _uiState.value.copy(
            errorMessage = error
        )
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    private fun setupDeepLinkCallbacks() {
        deepLinkService.setAuthCallbacks(
            onSuccess = { token, isNewUser ->
                onAuthSuccess(token, isNewUser)
            },
            onError = { error ->
                onAuthError(error)
            }
        )
    }
}