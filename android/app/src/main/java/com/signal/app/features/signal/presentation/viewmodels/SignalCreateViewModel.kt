package com.signal.app.features.signal.presentation.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.features.signal.data.models.*
import com.signal.app.features.signal.data.services.SignalApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject

/**
 * SignalCreateViewModel - 향상된 시그널 생성 ViewModel
 * iOS SignalCreateCubit과 동일한 기능을 Android에서 제공
 */
@HiltViewModel
class SignalCreateViewModel @Inject constructor(
    private val signalApiService: SignalApiService
) : ViewModel() {

    private val _uiState = MutableStateFlow(SignalCreateUiState())
    val uiState: StateFlow<SignalCreateUiState> = _uiState.asStateFlow()

    /**
     * 현재 단계 설정
     */
    fun setCurrentStep(step: Int) {
        _uiState.value = _uiState.value.copy(currentStep = step)
    }

    /**
     * 카테고리 선택
     */
    fun selectCategory(category: SignalCategory) {
        _uiState.value = _uiState.value.copy(
            selectedCategory = category,
            stepValidation = _uiState.value.stepValidation.toMutableMap().apply {
                this[0] = true
            }
        )
    }

    /**
     * 기본 정보 업데이트
     */
    fun updateBasicInfo(
        title: String,
        description: String,
        scheduledDateTime: LocalDateTime?,
        maxParticipants: Int
    ) {
        _uiState.value = _uiState.value.copy(
            title = title,
            description = description,
            scheduledDateTime = scheduledDateTime,
            maxParticipants = maxParticipants,
            stepValidation = _uiState.value.stepValidation.toMutableMap().apply {
                this[1] = isBasicInfoValid(title, scheduledDateTime)
            }
        )
    }

    /**
     * 위치 정보 업데이트
     */
    fun updateLocation(latitude: Double, longitude: Double, address: String, placeName: String?) {
        _uiState.value = _uiState.value.copy(
            latitude = latitude,
            longitude = longitude,
            address = address,
            placeName = placeName,
            stepValidation = _uiState.value.stepValidation.toMutableMap().apply {
                this[2] = true
            }
        )
    }

    /**
     * 설정 정보 업데이트
     */
    fun updateSettings(
        minAge: Int?,
        maxAge: Int?,
        genderPreference: String,
        allowInstantJoin: Boolean,
        requireApproval: Boolean
    ) {
        _uiState.value = _uiState.value.copy(
            minAge = minAge,
            maxAge = maxAge,
            genderPreference = genderPreference,
            allowInstantJoin = allowInstantJoin,
            requireApproval = requireApproval,
            stepValidation = _uiState.value.stepValidation.toMutableMap().apply {
                this[3] = true
            }
        )
    }

    /**
     * 시그널 생성
     */
    fun createSignal() {
        val currentState = _uiState.value
        
        if (!isAllStepsValid()) {
            _uiState.value = currentState.copy(
                status = SignalCreateStatus.FAILURE,
                error = "모든 필수 정보를 입력해주세요."
            )
            return
        }

        viewModelScope.launch {
            try {
                _uiState.value = currentState.copy(
                    status = SignalCreateStatus.LOADING,
                    error = null
                )

                val request = CreateSignalRequest(
                    title = currentState.title,
                    description = currentState.description,
                    category = currentState.selectedCategory!!.name.lowercase(),
                    latitude = currentState.latitude!!,
                    longitude = currentState.longitude!!,
                    address = currentState.address!!,
                    placeName = currentState.placeName,
                    scheduledAt = currentState.scheduledDateTime!!.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    maxParticipants = currentState.maxParticipants,
                    minAge = if (currentState.minAge == 0) null else currentState.minAge,
                    maxAge = if (currentState.maxAge == 100) null else currentState.maxAge,
                    allowInstantJoin = currentState.allowInstantJoin,
                    requireApproval = currentState.requireApproval,
                    genderPreference = if (currentState.genderPreference == "any") null else currentState.genderPreference
                )

                val response = signalApiService.createSignal(request)
                
                if (response.success && response.data != null) {
                    _uiState.value = currentState.copy(
                        status = SignalCreateStatus.SUCCESS,
                        createdSignal = response.data,
                        error = null
                    )
                } else {
                    _uiState.value = currentState.copy(
                        status = SignalCreateStatus.FAILURE,
                        error = response.message.ifEmpty { "시그널 생성에 실패했습니다." }
                    )
                }
            } catch (e: Exception) {
                _uiState.value = currentState.copy(
                    status = SignalCreateStatus.FAILURE,
                    error = e.message ?: "알 수 없는 오류가 발생했습니다."
                )
            }
        }
    }

    /**
     * 단계 유효성 검증
     */
    fun validateStep(step: Int): Boolean {
        return when (step) {
            0 -> _uiState.value.selectedCategory != null
            1 -> isBasicInfoValid(_uiState.value.title, _uiState.value.scheduledDateTime)
            2 -> _uiState.value.latitude != null && _uiState.value.address != null
            3 -> true // 설정 단계는 항상 유효 (기본값 사용)
            else -> false
        }
    }

    /**
     * 모든 단계 유효성 검증
     */
    private fun isAllStepsValid(): Boolean {
        return (0..3).all { validateStep(it) }
    }

    /**
     * 기본 정보 유효성 검증
     */
    private fun isBasicInfoValid(title: String, scheduledDateTime: LocalDateTime?): Boolean {
        return title.trim().length >= 5 && 
               scheduledDateTime != null && 
               scheduledDateTime.isAfter(LocalDateTime.now())
    }

    /**
     * 다음 단계로 이동 가능 여부
     */
    fun canProceedToNext(): Boolean {
        return validateStep(_uiState.value.currentStep)
    }

    /**
     * 마지막 단계 여부
     */
    fun isLastStep(): Boolean {
        return _uiState.value.currentStep == 3
    }

    /**
     * 단계 제목 가져오기
     */
    fun getStepTitle(step: Int): String {
        return when (step) {
            0 -> "관심사 선택"
            1 -> "상세 정보 입력"
            2 -> "장소 선택"
            3 -> "참여 설정"
            else -> ""
        }
    }

    /**
     * 에러 클리어
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    /**
     * 상태 리셋
     */
    fun reset() {
        _uiState.value = SignalCreateUiState()
    }
}

/**
 * SignalCreate UI 상태
 */
data class SignalCreateUiState(
    val status: SignalCreateStatus = SignalCreateStatus.INITIAL,
    val currentStep: Int = 0,
    val stepValidation: Map<Int, Boolean> = mapOf(
        0 to false,
        1 to false,
        2 to false,
        3 to true
    ),
    
    // Step 0: Category
    val selectedCategory: SignalCategory? = null,
    
    // Step 1: Basic Info
    val title: String = "",
    val description: String = "",
    val scheduledDateTime: LocalDateTime? = null,
    val maxParticipants: Int = 4,
    
    // Step 2: Location
    val latitude: Double? = null,
    val longitude: Double? = null,
    val address: String? = null,
    val placeName: String? = null,
    
    // Step 3: Settings
    val minAge: Int? = null,
    val maxAge: Int? = null,
    val genderPreference: String = "any", // any, male, female
    val allowInstantJoin: Boolean = true,
    val requireApproval: Boolean = false,
    
    // Result
    val createdSignal: Signal? = null,
    val error: String? = null
) {
    val totalSteps: Int = 4
    
    val progress: Float
        get() = (currentStep + 1) / totalSteps.toFloat()
        
    val isValid: Boolean
        get() = stepValidation[currentStep] ?: false
}

/**
 * 시그널 생성 상태
 */
enum class SignalCreateStatus {
    INITIAL,
    LOADING,
    SUCCESS,
    FAILURE
}