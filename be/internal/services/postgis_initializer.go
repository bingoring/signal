package services

import (
	"signal-module/pkg/logger"

	"gorm.io/gorm"
)

// PostGISInitializer PostGIS 확장 및 초기화 관리
type PostGISInitializer struct {
	db     *gorm.DB
	logger *logger.Logger
}

// NewPostGISInitializer 새 PostGIS 초기화기 생성
func NewPostGISInitializer(db *gorm.DB, logger *logger.Logger) *PostGISInitializer {
	return &PostGISInitializer{
		db:     db,
		logger: logger,
	}
}

// InitializePostGIS PostGIS 확장 설치 및 초기화
func (p *PostGISInitializer) InitializePostGIS() error {
	p.logger.Info("🗺️ PostGIS 확장 초기화 시작...")

	// PostGIS 확장 설치
	if err := p.enablePostGISExtension(); err != nil {
		return err
	}

	// 지리적 인덱스 최적화
	if err := p.optimizeGeographicIndexes(); err != nil {
		p.logger.Warn("지리적 인덱스 최적화 실패", err)
	}

	// 공간 참조 시스템 확인
	if err := p.verifySpatialReferenceSystems(); err != nil {
		p.logger.Warn("공간 참조 시스템 확인 실패", err)
	}

	p.logger.Info("✅ PostGIS 초기화 완료")
	return nil
}

// enablePostGISExtension PostGIS 확장 활성화
func (p *PostGISInitializer) enablePostGISExtension() error {
	extensions := []string{
		"CREATE EXTENSION IF NOT EXISTS postgis",
		"CREATE EXTENSION IF NOT EXISTS postgis_topology",
		"CREATE EXTENSION IF NOT EXISTS fuzzystrmatch",
		"CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder",
	}

	for _, ext := range extensions {
		if err := p.db.Exec(ext).Error; err != nil {
			p.logger.Warn("PostGIS 확장 설치 경고", err)
			// PostGIS 확장이 이미 설치되어 있거나 권한 문제일 수 있음
		}
	}

	// PostGIS 버전 확인
	var version string
	if err := p.db.Raw("SELECT PostGIS_Version()").Scan(&version).Error; err == nil {
		p.logger.Info("PostGIS 버전: " + version)
	}

	return nil
}

// optimizeGeographicIndexes 지리적 인덱스 최적화
func (p *PostGISInitializer) optimizeGeographicIndexes() error {
	optimizations := []string{
		// 시그널 위치 인덱스 최적화
		`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signals_location_optimized 
		 ON signals USING GIST (ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 3857))`,
		
		// 사용자 위치 인덱스 최적화
		`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_locations_optimized 
		 ON user_locations USING GIST (ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 3857))`,
		
		// 시간 및 위치 복합 인덱스
		`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signals_time_location 
		 ON signals USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), scheduled_at) 
		 WHERE status = 'active'`,

		// 카테고리 및 위치 복합 인덱스
		`CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_signals_category_location 
		 ON signals USING GIST (category, ST_SetSRID(ST_MakePoint(longitude, latitude), 4326))
		 WHERE status = 'active'`,
	}

	for _, optimization := range optimizations {
		if err := p.db.Exec(optimization).Error; err != nil {
			p.logger.Warn("지리적 인덱스 최적화 경고", err)
			// 인덱스가 이미 존재하거나 권한 문제일 수 있음
		}
	}

	return nil
}

// verifySpatialReferenceSystems 공간 참조 시스템 확인
func (p *PostGISInitializer) verifySpatialReferenceSystems() error {
	// WGS84 (EPSG:4326) 확인
	var count int64
	if err := p.db.Raw("SELECT COUNT(*) FROM spatial_ref_sys WHERE srid = 4326").Scan(&count).Error; err != nil {
		return err
	}

	if count == 0 {
		p.logger.Warn("WGS84 (EPSG:4326) 공간 참조 시스템이 없습니다")
	} else {
		p.logger.Info("✅ WGS84 공간 참조 시스템 확인됨")
	}

	// Web Mercator (EPSG:3857) 확인
	if err := p.db.Raw("SELECT COUNT(*) FROM spatial_ref_sys WHERE srid = 3857").Scan(&count).Error; err != nil {
		return err
	}

	if count == 0 {
		p.logger.Warn("Web Mercator (EPSG:3857) 공간 참조 시스템이 없습니다")
	} else {
		p.logger.Info("✅ Web Mercator 공간 참조 시스템 확인됨")
	}

	return nil
}

// GetPostGISInfo PostGIS 정보 조회
func (p *PostGISInitializer) GetPostGISInfo() (map[string]interface{}, error) {
	info := make(map[string]interface{})

	// PostGIS 버전
	var version string
	if err := p.db.Raw("SELECT PostGIS_Version()").Scan(&version).Error; err == nil {
		info["postgis_version"] = version
	}

	// GEOS 버전
	var geosVersion string
	if err := p.db.Raw("SELECT PostGIS_GEOS_Version()").Scan(&geosVersion).Error; err == nil {
		info["geos_version"] = geosVersion
	}

	// PROJ 버전
	var projVersion string
	if err := p.db.Raw("SELECT PostGIS_Proj_Version()").Scan(&projVersion).Error; err == nil {
		info["proj_version"] = projVersion
	}

	// 사용 가능한 공간 참조 시스템 수
	var srsCount int64
	if err := p.db.Raw("SELECT COUNT(*) FROM spatial_ref_sys").Scan(&srsCount).Error; err == nil {
		info["spatial_reference_systems"] = srsCount
	}

	// 지리적 인덱스 정보
	var indexInfo []map[string]interface{}
	rows, err := p.db.Raw(`
		SELECT 
			schemaname,
			tablename,
			indexname,
			indexdef
		FROM pg_indexes 
		WHERE indexdef LIKE '%gist%' 
		  AND (tablename = 'signals' OR tablename = 'user_locations')
		ORDER BY tablename, indexname
	`).Rows()

	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var schema, table, index, definition string
			if err := rows.Scan(&schema, &table, &index, &definition); err == nil {
				indexInfo = append(indexInfo, map[string]interface{}{
					"schema":     schema,
					"table":      table,
					"index":      index,
					"definition": definition,
				})
			}
		}
		info["geographic_indexes"] = indexInfo
	}

	return info, nil
}

// ValidateGeographicData 지리적 데이터 유효성 검사
func (p *PostGISInitializer) ValidateGeographicData() error {
	// 잘못된 좌표 데이터 확인
	var invalidSignals int64
	if err := p.db.Raw(`
		SELECT COUNT(*) FROM signals 
		WHERE latitude NOT BETWEEN -90 AND 90 
		   OR longitude NOT BETWEEN -180 AND 180
		   OR latitude = 0 AND longitude = 0
	`).Scan(&invalidSignals).Error; err != nil {
		return err
	}

	if invalidSignals > 0 {
		p.logger.Warn("⚠️ 잘못된 시그널 좌표 발견", map[string]interface{}{
			"count": invalidSignals,
		})
	}

	// 잘못된 사용자 위치 데이터 확인
	var invalidLocations int64
	if err := p.db.Raw(`
		SELECT COUNT(*) FROM user_locations 
		WHERE latitude NOT BETWEEN -90 AND 90 
		   OR longitude NOT BETWEEN -180 AND 180
		   OR latitude = 0 AND longitude = 0
	`).Scan(&invalidLocations).Error; err != nil {
		return err
	}

	if invalidLocations > 0 {
		p.logger.Warn("⚠️ 잘못된 사용자 위치 좌표 발견", map[string]interface{}{
			"count": invalidLocations,
		})
	}

	p.logger.Info("✅ 지리적 데이터 유효성 검사 완료", map[string]interface{}{
		"invalid_signals":   invalidSignals,
		"invalid_locations": invalidLocations,
	})

	return nil
}

// GetGeographicStatistics 지리적 통계 정보 조회
func (p *PostGISInitializer) GetGeographicStatistics() (map[string]interface{}, error) {
	stats := make(map[string]interface{})

	// 총 시그널 수
	var totalSignals int64
	if err := p.db.Raw("SELECT COUNT(*) FROM signals WHERE status = 'active'").Scan(&totalSignals).Error; err == nil {
		stats["total_active_signals"] = totalSignals
	}

	// 지리적 범위 계산
	var bounds struct {
		MinLat float64 `json:"min_lat"`
		MaxLat float64 `json:"max_lat"`
		MinLon float64 `json:"min_lon"`
		MaxLon float64 `json:"max_lon"`
	}

	if err := p.db.Raw(`
		SELECT 
			MIN(latitude) as min_lat,
			MAX(latitude) as max_lat,
			MIN(longitude) as min_lon,
			MAX(longitude) as max_lon
		FROM signals 
		WHERE status = 'active'
		  AND latitude BETWEEN -90 AND 90
		  AND longitude BETWEEN -180 AND 180
	`).Scan(&bounds).Error; err == nil {
		stats["geographic_bounds"] = bounds
	}

	// 카테고리별 분포
	var categoryDistribution []map[string]interface{}
	rows, err := p.db.Raw(`
		SELECT 
			category,
			COUNT(*) as count,
			AVG(latitude) as avg_lat,
			AVG(longitude) as avg_lon
		FROM signals 
		WHERE status = 'active'
		GROUP BY category
		ORDER BY count DESC
	`).Rows()

	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var category string
			var count int64
			var avgLat, avgLon float64
			if err := rows.Scan(&category, &count, &avgLat, &avgLon); err == nil {
				categoryDistribution = append(categoryDistribution, map[string]interface{}{
					"category":  category,
					"count":     count,
					"avg_lat":   avgLat,
					"avg_lon":   avgLon,
				})
			}
		}
		stats["category_distribution"] = categoryDistribution
	}

	return stats, nil
}