package utils

import "math"

// IsWithinKorea 한국 내 좌표인지 확인 (대략적인 경계)
func IsWithinKorea(lat, lon float64) bool {
	// 한국의 대략적인 경계
	// 북위 33-38도, 동경 124-132도
	return lat >= 33.0 && lat <= 38.5 && lon >= 124.0 && lon <= 132.0
}

// GetBoundingBox 중심점과 반경을 기준으로 경계 박스 계산
func GetBoundingBox(centerLat, centerLon, radiusMeters float64) (minLat, maxLat, minLon, maxLon float64) {
	// 1도당 약 111,320미터
	latDelta := radiusMeters / 111320.0
	// 경도는 위도에 따라 달라짐
	lonDelta := radiusMeters / (111320.0 * math.Cos(centerLat*math.Pi/180))

	minLat = centerLat - latDelta
	maxLat = centerLat + latDelta
	minLon = centerLon - lonDelta
	maxLon = centerLon + lonDelta

	return
}

// ValidateAddress 주소 유효성 검사
func ValidateAddress(address string) bool {
	if len(address) < 5 || len(address) > 200 {
		return false
	}
	// 추가 주소 형식 검증 로직이 필요하면 여기에 구현
	return true
}