package com.signal.app.features.signal.data.models

import com.google.gson.annotations.SerializedName
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Signal 데이터 모델 - Flutter SignalModel과 동일한 구조
 */
data class Signal(
    val id: Int,
    val title: String,
    val description: String,
    val category: String,
    val latitude: Double,
    val longitude: Double,
    val address: String,
    @SerializedName("max_participants")
    val maxParticipants: Int,
    @SerializedName("current_participants")
    val currentParticipants: Int,
    @SerializedName("scheduled_time")
    val scheduledTime: String?, // ISO 8601 format
    @SerializedName("is_private")
    val isPrivate: Boolean,
    val status: SignalStatus,
    val tags: List<String>,
    @SerializedName("creator_id")
    val creatorId: Int,
    @SerializedName("creator_name")
    val creatorName: String,
    @SerializedName("created_at")
    val createdAt: String, // ISO 8601 format
    @SerializedName("updated_at")
    val updatedAt: String, // ISO 8601 format
    @SerializedName("expires_at")
    val expiresAt: String? = null // ISO 8601 format
) {
    /**
     * 예약된 시간이 있는지 확인
     */
    fun hasScheduledTime(): Boolean = !scheduledTime.isNullOrEmpty()

    /**
     * 시그널이 활성 상태인지 확인
     */
    fun isActive(): Boolean = status == SignalStatus.ACTIVE

    /**
     * 시그널이 완료된 상태인지 확인
     */
    fun isCompleted(): Boolean = status == SignalStatus.COMPLETED

    /**
     * 참여 가능한 상태인지 확인
     */
    fun canJoin(): Boolean = isActive() && currentParticipants < maxParticipants

    /**
     * 만료 시간이 있는지 확인
     */
    fun hasExpiration(): Boolean = !expiresAt.isNullOrEmpty()

    /**
     * 시그널이 만료되었는지 확인
     */
    fun isExpired(): Boolean {
        return if (!expiresAt.isNullOrEmpty()) {
            try {
                val expireTime = LocalDateTime.parse(expiresAt, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                LocalDateTime.now().isAfter(expireTime)
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }

    /**
     * 예약된 시간까지의 시간 차이 (분)
     */
    fun getMinutesUntilScheduled(): Long? {
        return if (!scheduledTime.isNullOrEmpty()) {
            try {
                val scheduled = LocalDateTime.parse(scheduledTime, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                val now = LocalDateTime.now()
                java.time.Duration.between(now, scheduled).toMinutes()
            } catch (e: Exception) {
                null
            }
        } else {
            null
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