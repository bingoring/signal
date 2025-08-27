-- Signal 데이터베이스 초기 설정

-- PostGIS 확장 (지리적 위치 기능)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 전체 텍스트 검색을 위한 확장
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- UUID 생성을 위한 확장
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 인덱스 성능 향상을 위한 설정
CREATE EXTENSION IF NOT EXISTS btree_gist;