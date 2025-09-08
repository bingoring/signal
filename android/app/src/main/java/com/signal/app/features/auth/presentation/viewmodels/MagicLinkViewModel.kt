package com.signal.app.features.auth.presentation.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.features.auth.data.services.AuthService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class MagicLinkUiState(
    val email: String = "",
    val isLoading: Boolean = false,
    val emailSent: Boolean = false,
    val errorMessage: String? = null
)

@HiltViewModel
class MagicLinkViewModel @Inject constructor(
    private val authService: AuthService
) : ViewModel() {

    private val _uiState = MutableStateFlow(MagicLinkUiState())
    val uiState: StateFlow<MagicLinkUiState> = _uiState.asStateFlow()

    private var onAuthSuccess: ((String, Boolean) -> Unit)? = null
    private var onAuthError: ((String) -> Unit)? = null

    fun setCallbacks(
        onSuccess: (String, Boolean) -> Unit,
        onError: (String) -> Unit
    ) {
        onAuthSuccess = onSuccess
        onAuthError = onError
    }

    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(
            email = email,
            errorMessage = null
        )
    }

    fun sendMagicLink() {
        val email = _uiState.value.email.trim()
        
        if (email.isEmpty()) {
            _uiState.value = _uiState.value.copy(
                errorMessage = "이메일 주소를 입력해주세요"
            )
            return
        }

        if (!isValidEmail(email)) {
            _uiState.value = _uiState.value.copy(
                errorMessage = "유효한 이메일 주소를 입력해주세요"
            )
            return
        }

        _uiState.value = _uiState.value.copy(
            isLoading = true,
            errorMessage = null
        )

        viewModelScope.launch {
            try {
                authService.sendMagicLink(email)
                _uiState.value = _uiState.value.copy(
                    emailSent = true,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = e.message?.replace("Exception: ", "") ?: "매직링크 전송에 실패했습니다."
                )
                onAuthError?.invoke(_uiState.value.errorMessage ?: "Unknown error")
            }
        }
    }

    fun resetForm() {
        _uiState.value = MagicLinkUiState()
    }

    private fun isValidEmail(email: String): Boolean {
        return android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()
    }
}