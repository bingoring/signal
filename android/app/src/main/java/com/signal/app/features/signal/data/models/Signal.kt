package com.signal.app.features.signal.data.models

import com.google.gson.annotations.SerializedName
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Enhanced Signal 데이터 모델 - iOS SignalModel과 동일한 구조
 */
data class Signal(
    val id: Int,
    val title: String,
    val description: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
    val address: String,
    @SerializedName("place_name")
    val placeName: String?,
    @SerializedName("scheduled_at")
    val scheduledAt: String, // ISO 8601 format
    @SerializedName("expires_at")
    val expiresAt: String, // ISO 8601 format
    @SerializedName("max_participants")
    val maxParticipants: Int,
    @SerializedName("current_participants")
    val currentParticipants: Int,
    @SerializedName("min_age")
    val minAge: Int?,
    @SerializedName("max_age")
    val maxAge: Int?,
    @SerializedName("allow_instant_join")
    val allowInstantJoin: Boolean,
    @SerializedName("require_approval")
    val requireApproval: Boolean,
    @SerializedName("gender_preference")
    val genderPreference: String?,
    val status: String,
    @SerializedName("created_at")
    val createdAt: String, // ISO 8601 format
    @SerializedName("updated_at")
    val updatedAt: String, // ISO 8601 format
    val creator: UserModel,
    val distance: Double? = null // 미터 단위
) {
    /**
     * 예약된 시간이 있는지 확인
     */
    fun hasScheduledTime(): Boolean = scheduledAt.isNotEmpty()

    /**
     * 시그널이 활성 상태인지 확인
     */
    fun isActive(): Boolean = status == "active"

    /**
     * 시그널이 완료된 상태인지 확인
     */
    fun isCompleted(): Boolean = status == "completed"

    /**
     * 참여 가능한 상태인지 확인
     */
    fun canJoin(): Boolean = isActive() && currentParticipants < maxParticipants

    /**
     * 만료 시간이 있는지 확인
     */
    fun hasExpiration(): Boolean = expiresAt.isNotEmpty()

    /**
     * 시그널이 만료되었는지 확인
     */
    fun isExpired(): Boolean {
        return try {
            val expireTime = LocalDateTime.parse(expiresAt, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            LocalDateTime.now().isAfter(expireTime)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 예약된 시간까지의 시간 차이 (분)
     */
    fun getMinutesUntilScheduled(): Long? {
        return try {
            val scheduled = LocalDateTime.parse(scheduledAt, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
            val now = LocalDateTime.now()
            java.time.Duration.between(now, scheduled).toMinutes()
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 성별 선호도 표시 이름
     */
    fun getGenderPreferenceDisplayName(): String {
        return when (genderPreference) {
            "male" -> "남성만"
            "female" -> "여성만"
            else -> "성별 무관"
        }
    }

    /**
     * 연령대 범위 표시
     */
    fun getAgeRangeDisplayName(): String {
        return when {
            minAge == null && maxAge == null -> "전 연령"
            minAge == null -> "${maxAge}세 이하"
            maxAge == null -> "${minAge}세 이상"
            else -> "${minAge}세 - ${maxAge}세"
        }
    }

    /**
     * 참가 방식 표시 이름
     */
    fun getJoinMethodDisplayName(): String {
        return when {
            allowInstantJoin -> "즉시 참가"
            requireApproval -> "승인 필요"
            else -> "자유 참가"
        }
    }
}

/**
 * 거리 정보와 함께 제공되는 Signal 모델
 */
data class SignalWithDistance(
    val signal: Signal,
    val distance: Double? = null // 미터 단위
) {
    /**
     * 거리를 킬로미터로 변환
     */
    fun getDistanceInKm(): Double? = distance?.div(1000.0)

    /**
     * 거리를 사용자 친화적 문자열로 변환
     */
    fun getFormattedDistance(): String? {
        return distance?.let { dist ->
            when {
                dist < 1000 -> "${dist.toInt()}m"
                dist < 10000 -> String.format("%.1fkm", dist / 1000.0)
                else -> "${(dist / 1000.0).toInt()}km"
            }
        }
    }

    /**
     * 거리별 색상 구분을 위한 거리 레벨
     */
    fun getDistanceLevel(): DistanceLevel {
        return when (distance) {
            null -> DistanceLevel.UNKNOWN
            in 0.0..500.0 -> DistanceLevel.VERY_CLOSE
            in 500.0..1000.0 -> DistanceLevel.CLOSE
            in 1000.0..3000.0 -> DistanceLevel.MEDIUM
            in 3000.0..10000.0 -> DistanceLevel.FAR
            else -> DistanceLevel.VERY_FAR
        }
    }
}

/**
 * 시그널 상태
 */
enum class SignalStatus {
    @SerializedName("active")
    ACTIVE,
    
    @SerializedName("completed")
    COMPLETED,
    
    @SerializedName("cancelled")
    CANCELLED,
    
    @SerializedName("expired")
    EXPIRED
}

/**
 * 거리 레벨
 */
enum class DistanceLevel {
    UNKNOWN,
    VERY_CLOSE,  // 0-500m
    CLOSE,       // 500m-1km
    MEDIUM,      // 1-3km
    FAR,         // 3-10km
    VERY_FAR     // 10km+
}

/**
 * 시그널 카테고리
 */
enum class SignalCategory(val displayName: String, val icon: String) {
    FOOD("맛집", "restaurant"),
    COFFEE("카페", "local_cafe"),
    CULTURE("문화", "theater_comedy"),
    SPORTS("스포츠", "sports_soccer"),
    STUDY("스터디", "school"),
    WORK("업무", "work"),
    SOCIAL("모임", "groups"),
    TRAVEL("여행", "flight"),
    SHOPPING("쇼핑", "shopping_cart"),
    OTHER("기타", "more_horiz");

    companion object {
        fun fromString(category: String): SignalCategory {
            return entries.find { it.name.equals(category, ignoreCase = true) } ?: OTHER
        }
    }
}

/**
 * 지도 범위 모델
 */
data class MapBounds(
    val minLat: Double,
    val maxLat: Double,
    val minLon: Double,
    val maxLon: Double
) {
    /**
     * 좌표가 범위 내에 있는지 확인
     */
    fun contains(latitude: Double, longitude: Double): Boolean {
        return latitude in minLat..maxLat && longitude in minLon..maxLon
    }

    /**
     * 범위의 중심점 계산
     */
    fun getCenter(): Pair<Double, Double> {
        return Pair((minLat + maxLat) / 2.0, (minLon + maxLon) / 2.0)
    }
}

/**
 * 사용자 모델
 */
data class UserModel(
    val id: Int,
    val email: String,
    val username: String?,
    @SerializedName("is_active")
    val isActive: Boolean,
    val profile: UserProfileModel?
)

/**
 * 사용자 프로필 모델
 */
data class UserProfileModel(
    @SerializedName("display_name")
    val displayName: String?,
    val bio: String?,
    @SerializedName("profile_image_url")
    val profileImageUrl: String?,
    val age: Int,
    val gender: String,
    @SerializedName("manner_score")
    val mannerScore: Double,
    @SerializedName("total_ratings")
    val totalRatings: Int
)

/**
 * 시그널 참가 신청서 모델
 */
data class SignalJoinRequest(
    val id: Int,
    @SerializedName("signal_id")
    val signalId: Int,
    @SerializedName("user_id")
    val userId: Int,
    val user: UserModel?,
    val message: String?,
    val status: String, // pending, approved, rejected, expired
    @SerializedName("response_message")
    val responseMessage: String?,
    @SerializedName("created_at")
    val createdAt: String,
    @SerializedName("updated_at")
    val updatedAt: String
) {
    fun isPending(): Boolean = status == "pending"
    fun isApproved(): Boolean = status == "approved"
    fun isRejected(): Boolean = status == "rejected"
    fun isExpired(): Boolean = status == "expired"
}

/**
 * 시그널 생성 요청 모델
 */
data class CreateSignalRequest(
    val title: String,
    val description: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
    val address: String,
    @SerializedName("place_name")
    val placeName: String?,
    @SerializedName("scheduled_at")
    val scheduledAt: String, // ISO 8601 format
    @SerializedName("max_participants")
    val maxParticipants: Int,
    @SerializedName("min_age")
    val minAge: Int?,
    @SerializedName("max_age")
    val maxAge: Int?,
    @SerializedName("allow_instant_join")
    val allowInstantJoin: Boolean,
    @SerializedName("require_approval")
    val requireApproval: Boolean,
    @SerializedName("gender_preference")
    val genderPreference: String?
)

/**
 * 시그널 참가 신청 요청 모델
 */
data class JoinSignalRequest(
    val message: String?
)

/**
 * 참가 신청 승인 요청 모델
 */
data class ApproveJoinRequestRequest(
    @SerializedName("user_id")
    val userId: Int,
    val message: String?
)

/**
 * 참가 신청 거절 요청 모델
 */
data class RejectJoinRequestRequest(
    @SerializedName("user_id")
    val userId: Int,
    val reason: String
)

/**
 * API 응답 래퍼 모델
 */
data class ApiResponse<T>(
    val success: Boolean,
    val message: String,
    val data: T?
)