package com.signal.app.features.signal.presentation.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.features.signal.data.models.*
import com.signal.app.features.signal.data.services.SignalApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * JoinRequestViewModel - 시그널 참가 신청 관리 ViewModel
 * iOS JoinRequestCubit과 동일한 기능을 Android에서 제공
 */
@HiltViewModel
class JoinRequestViewModel @Inject constructor(
    private val signalApiService: SignalApiService
) : ViewModel() {

    private val _uiState = MutableStateFlow(JoinRequestUiState())
    val uiState: StateFlow<JoinRequestUiState> = _uiState.asStateFlow()

    /**
     * 참가 신청서 목록 로드
     */
    fun loadJoinRequests(signalId: Int) {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(
                    status = JoinRequestStatus.LOADING,
                    error = null
                )

                val response = signalApiService.getJoinRequests(signalId)
                
                if (response.success && response.data != null) {
                    _uiState.value = _uiState.value.copy(
                        status = JoinRequestStatus.LOADED,
                        joinRequests = response.data,
                        error = null
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        status = JoinRequestStatus.ERROR,
                        error = response.message.ifEmpty { "참가 신청서를 불러올 수 없습니다." }
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    status = JoinRequestStatus.ERROR,
                    error = e.message ?: "알 수 없는 오류가 발생했습니다."
                )
            }
        }
    }

    /**
     * 참가 신청 제출
     */
    fun submitJoinRequest(signalId: Int, message: String?) {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(
                    submitStatus = SubmitStatus.SUBMITTING,
                    submitError = null
                )

                val request = JoinSignalRequest(message = message)
                val response = signalApiService.joinSignal(signalId, request)
                
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        submitStatus = SubmitStatus.SUBMITTED,
                        submitError = null
                    )
                    
                    // 신청 후 목록 새로고침
                    loadJoinRequests(signalId)
                } else {
                    _uiState.value = _uiState.value.copy(
                        submitStatus = SubmitStatus.FAILED,
                        submitError = response.message.ifEmpty { "참가 신청에 실패했습니다." }
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    submitStatus = SubmitStatus.FAILED,
                    submitError = e.message ?: "알 수 없는 오류가 발생했습니다."
                )
            }
        }
    }

    /**
     * 참가 신청 승인
     */
    fun approveJoinRequest(signalId: Int, userId: Int, message: String?) {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(
                    actionStatus = ActionStatus.PROCESSING,
                    actionError = null
                )

                val request = ApproveJoinRequestRequest(userId = userId, message = message)
                val response = signalApiService.approveJoinRequest(signalId, request)
                
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        actionStatus = ActionStatus.SUCCESS,
                        actionError = null
                    )
                    
                    // 승인 후 목록 새로고침
                    loadJoinRequests(signalId)
                } else {
                    _uiState.value = _uiState.value.copy(
                        actionStatus = ActionStatus.FAILED,
                        actionError = response.message.ifEmpty { "승인에 실패했습니다." }
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    actionStatus = ActionStatus.FAILED,
                    actionError = e.message ?: "알 수 없는 오류가 발생했습니다."
                )
            }
        }
    }

    /**
     * 참가 신청 거절
     */
    fun rejectJoinRequest(signalId: Int, userId: Int, reason: String) {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(
                    actionStatus = ActionStatus.PROCESSING,
                    actionError = null
                )

                val request = RejectJoinRequestRequest(userId = userId, reason = reason)
                val response = signalApiService.rejectJoinRequest(signalId, request)
                
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        actionStatus = ActionStatus.SUCCESS,
                        actionError = null
                    )
                    
                    // 거절 후 목록 새로고침
                    loadJoinRequests(signalId)
                } else {
                    _uiState.value = _uiState.value.copy(
                        actionStatus = ActionStatus.FAILED,
                        actionError = response.message.ifEmpty { "거절에 실패했습니다." }
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    actionStatus = ActionStatus.FAILED,
                    actionError = e.message ?: "알 수 없는 오류가 발생했습니다."
                )
            }
        }
    }

    /**
     * 내 참가 신청 상태 조회
     */
    fun loadMyJoinStatus(signalId: Int) {
        viewModelScope.launch {
            try {
                val response = signalApiService.getMyJoinStatus(signalId)
                
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        myJoinRequest = response.data
                    )
                }
            } catch (e: Exception) {
                // 조용히 실패 - 이는 선택적 기능이므로
            }
        }
    }

    /**
     * 제출 상태 클리어
     */
    fun clearSubmitStatus() {
        _uiState.value = _uiState.value.copy(
            submitStatus = SubmitStatus.INITIAL,
            submitError = null
        )
    }

    /**
     * 액션 상태 클리어
     */
    fun clearActionStatus() {
        _uiState.value = _uiState.value.copy(
            actionStatus = ActionStatus.INITIAL,
            actionError = null
        )
    }

    /**
     * 전체 상태 리셋
     */
    fun reset() {
        _uiState.value = JoinRequestUiState()
    }

    // 필터링 헬퍼 프로퍼티들
    val pendingRequests: List<SignalJoinRequest>
        get() = _uiState.value.joinRequests.filter { it.isPending() }

    val approvedRequests: List<SignalJoinRequest>
        get() = _uiState.value.joinRequests.filter { it.isApproved() }

    val rejectedRequests: List<SignalJoinRequest>
        get() = _uiState.value.joinRequests.filter { it.isRejected() }

    /**
     * 사용자가 신청했는지 확인
     */
    fun hasUserRequested(userId: Int): Boolean {
        return _uiState.value.joinRequests.any { 
            it.userId == userId && !it.isRejected()
        }
    }

    /**
     * 사용자의 신청서 가져오기
     */
    fun getUserRequest(userId: Int): SignalJoinRequest? {
        return _uiState.value.joinRequests.find { it.userId == userId }
    }
}

/**
 * JoinRequest UI 상태
 */
data class JoinRequestUiState(
    val status: JoinRequestStatus = JoinRequestStatus.INITIAL,
    val joinRequests: List<SignalJoinRequest> = emptyList(),
    val myJoinRequest: SignalJoinRequest? = null,
    val submitStatus: SubmitStatus = SubmitStatus.INITIAL,
    val submitError: String? = null,
    val actionStatus: ActionStatus = ActionStatus.INITIAL,
    val actionError: String? = null,
    val error: String? = null
)

/**
 * 참가 신청서 로드 상태
 */
enum class JoinRequestStatus {
    INITIAL,
    LOADING,
    LOADED,
    ERROR
}

/**
 * 제출 상태
 */
enum class SubmitStatus {
    INITIAL,
    SUBMITTING,
    SUBMITTED,
    FAILED
}

/**
 * 액션 상태 (승인/거절)
 */
enum class ActionStatus {
    INITIAL,
    PROCESSING,
    SUCCESS,
    FAILED
}