package utils

import (
	"fmt"
	"math"
)

// 두 지점 간의 거리 계산 (Haversine formula)
// 결과는 미터 단위
func CalculateDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadius = 6371000 // 지구 반지름 (미터)

	// 라디안으로 변환
	lat1Rad := lat1 * math.Pi / 180
	lng1Rad := lng1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	lng2Rad := lng2 * math.Pi / 180

	// 위도와 경도의 차이
	deltaLat := lat2Rad - lat1Rad
	deltaLng := lng2Rad - lng1Rad

	// Haversine 공식
	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLng/2)*math.Sin(deltaLng/2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}

// 거리가 지정된 반경 내에 있는지 확인
func IsWithinRadius(lat1, lng1, lat2, lng2, radius float64) bool {
	distance := CalculateDistance(lat1, lng1, lat2, lng2)
	return distance <= radius
}

// 거리를 사용자 친화적인 문자열로 변환
func FormatDistance(meters float64) string {
	if meters < 1000 {
		return fmt.Sprintf("%.0fm", meters)
	}
	return fmt.Sprintf("%.1fkm", meters/1000)
}

// 좌표 유효성 검사
func IsValidCoordinate(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

// 한국 범위 내 좌표인지 확인 (대략적)
func IsInKorea(lat, lng float64) bool {
	// 한국의 대략적인 경계
	// 위도: 33.0 ~ 38.6
	// 경도: 125.0 ~ 131.9
	return lat >= 33.0 && lat <= 38.6 && lng >= 125.0 && lng <= 131.9
}