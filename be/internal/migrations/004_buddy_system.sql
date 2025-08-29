-- Migration: 004_buddy_system.sql
-- 단골 시스템 관련 테이블 생성

-- 단골 관계 테이블
CREATE TABLE user_buddies (
    id SERIAL PRIMARY KEY,
    user1_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    last_interaction TIMESTAMP DEFAULT NOW(),
    interaction_count INTEGER DEFAULT 1,
    total_signals INTEGER DEFAULT 1, -- 함께 참여한 총 시그널 수
    compatibility_score DECIMAL(3,1) DEFAULT 5.0, -- 궁합 점수 (0-10)
    status VARCHAR(20) DEFAULT 'active', -- active, paused, blocked
    notes TEXT, -- 개인 메모 (선택사항)
    
    -- 같은 두 사용자 관계는 한 번만 존재 (순서 무관)
    CONSTRAINT unique_buddy_pair UNIQUE(LEAST(user1_id, user2_id), GREATEST(user1_id, user2_id)),
    -- 자기 자신과는 단골이 될 수 없음
    CONSTRAINT no_self_buddy CHECK (user1_id != user2_id)
);

-- 단골 관계 인덱스
CREATE INDEX idx_user_buddies_user1 ON user_buddies (user1_id);
CREATE INDEX idx_user_buddies_user2 ON user_buddies (user2_id);
CREATE INDEX idx_user_buddies_status ON user_buddies (status);
CREATE INDEX idx_user_buddies_compatibility ON user_buddies (compatibility_score DESC);
CREATE INDEX idx_user_buddies_last_interaction ON user_buddies (last_interaction DESC);

-- 매너 점수 이력 테이블 (기존 user_ratings 확장)
CREATE TABLE manner_score_logs (
    id SERIAL PRIMARY KEY,
    signal_id INTEGER REFERENCES signals(id) ON DELETE SET NULL,
    rater_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ratee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    score_change DECIMAL(3,1) NOT NULL, -- 점수 변화량 (-5.0 ~ +5.0)
    category VARCHAR(50) NOT NULL, -- punctuality, communication, kindness, participation
    reason TEXT, -- 평가 이유 (선택사항)
    is_positive BOOLEAN GENERATED ALWAYS AS (score_change > 0) STORED,
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- 같은 시그널에서 같은 사람을 중복 평가 방지
    CONSTRAINT unique_rating_per_signal UNIQUE(signal_id, rater_id, ratee_id),
    -- 자기 자신을 평가할 수 없음
    CONSTRAINT no_self_rating CHECK (rater_id != ratee_id),
    -- 점수 변화량 범위 제한
    CONSTRAINT valid_score_change CHECK (score_change >= -5.0 AND score_change <= 5.0)
);

-- 매너 점수 이력 인덱스
CREATE INDEX idx_manner_logs_ratee ON manner_score_logs (ratee_id);
CREATE INDEX idx_manner_logs_rater ON manner_score_logs (rater_id);
CREATE INDEX idx_manner_logs_signal ON manner_score_logs (signal_id);
CREATE INDEX idx_manner_logs_category ON manner_score_logs (category);
CREATE INDEX idx_manner_logs_created ON manner_score_logs (created_at DESC);

-- 시그널 참여 이력 테이블 (관계 형성 추적)
CREATE TABLE signal_interactions (
    id SERIAL PRIMARY KEY,
    signal_id INTEGER NOT NULL REFERENCES signals(id) ON DELETE CASCADE,
    user1_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) DEFAULT 'participated', -- participated, completed, no_show
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- 같은 시그널에서 같은 두 사용자 상호작용은 한 번만
    CONSTRAINT unique_interaction_per_signal UNIQUE(signal_id, LEAST(user1_id, user2_id), GREATEST(user1_id, user2_id)),
    -- 자기 자신과는 상호작용 불가
    CONSTRAINT no_self_interaction CHECK (user1_id != user2_id)
);

-- 시그널 상호작용 인덱스
CREATE INDEX idx_signal_interactions_signal ON signal_interactions (signal_id);
CREATE INDEX idx_signal_interactions_users ON signal_interactions (user1_id, user2_id);
CREATE INDEX idx_signal_interactions_type ON signal_interactions (interaction_type);

-- 단골 초대 테이블 (단골이 새 시그널에 초대하는 기능)
CREATE TABLE buddy_invitations (
    id SERIAL PRIMARY KEY,
    signal_id INTEGER NOT NULL REFERENCES signals(id) ON DELETE CASCADE,
    inviter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, declined, expired
    message TEXT, -- 초대 메시지
    expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '24 hours',
    created_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP,
    
    -- 같은 시그널에 같은 사람을 중복 초대 방지
    CONSTRAINT unique_invitation UNIQUE(signal_id, inviter_id, invitee_id),
    -- 자기 자신을 초대할 수 없음
    CONSTRAINT no_self_invitation CHECK (inviter_id != invitee_id)
);

-- 단골 초대 인덱스
CREATE INDEX idx_buddy_invitations_invitee ON buddy_invitations (invitee_id);
CREATE INDEX idx_buddy_invitations_inviter ON buddy_invitations (inviter_id);
CREATE INDEX idx_buddy_invitations_signal ON buddy_invitations (signal_id);
CREATE INDEX idx_buddy_invitations_status ON buddy_invitations (status);
CREATE INDEX idx_buddy_invitations_expires ON buddy_invitations (expires_at);

-- 사용자 프로필에 단골 통계 필드 추가
ALTER TABLE user_profiles 
ADD COLUMN buddy_count INTEGER DEFAULT 0,
ADD COLUMN total_interactions INTEGER DEFAULT 0,
ADD COLUMN preferred_activity_types TEXT[], -- 선호 활동 타입 배열
ADD COLUMN last_active_at TIMESTAMP DEFAULT NOW();

-- 단골 통계 업데이트 트리거 함수
CREATE OR REPLACE FUNCTION update_buddy_stats() 
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- 새로운 단골 관계 생성 시
        UPDATE user_profiles 
        SET buddy_count = buddy_count + 1 
        WHERE user_id = NEW.user1_id OR user_id = NEW.user2_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- 단골 관계 삭제 시
        UPDATE user_profiles 
        SET buddy_count = buddy_count - 1 
        WHERE user_id = OLD.user1_id OR user_id = OLD.user2_id;
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'blocked' AND OLD.status = 'active' THEN
        -- 단골 관계 차단 시
        UPDATE user_profiles 
        SET buddy_count = buddy_count - 1 
        WHERE user_id = NEW.user1_id OR user_id = NEW.user2_id;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' AND NEW.status = 'active' AND OLD.status = 'blocked' THEN
        -- 단골 관계 차단 해제 시
        UPDATE user_profiles 
        SET buddy_count = buddy_count + 1 
        WHERE user_id = NEW.user1_id OR user_id = NEW.user2_id;
        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 단골 통계 업데이트 트리거
CREATE TRIGGER trigger_update_buddy_stats
    AFTER INSERT OR UPDATE OR DELETE ON user_buddies
    FOR EACH ROW EXECUTE FUNCTION update_buddy_stats();

-- 단골 관계 조회를 위한 뷰
CREATE VIEW buddy_relationships AS
SELECT 
    ub.id,
    CASE 
        WHEN ub.user1_id < ub.user2_id THEN ub.user1_id 
        ELSE ub.user2_id 
    END as user_id,
    CASE 
        WHEN ub.user1_id < ub.user2_id THEN ub.user2_id 
        ELSE ub.user1_id 
    END as buddy_id,
    ub.created_at,
    ub.last_interaction,
    ub.interaction_count,
    ub.total_signals,
    ub.compatibility_score,
    ub.status,
    u1.username as user_name,
    u2.username as buddy_name,
    up1.display_name as user_display_name,
    up2.display_name as buddy_display_name,
    up1.manner_score as user_manner_score,
    up2.manner_score as buddy_manner_score
FROM user_buddies ub
JOIN users u1 ON u1.id = CASE WHEN ub.user1_id < ub.user2_id THEN ub.user1_id ELSE ub.user2_id END
JOIN users u2 ON u2.id = CASE WHEN ub.user1_id < ub.user2_id THEN ub.user2_id ELSE ub.user1_id END
LEFT JOIN user_profiles up1 ON up1.user_id = u1.id
LEFT JOIN user_profiles up2 ON up2.user_id = u2.id;

-- 단골 추천을 위한 함수
CREATE OR REPLACE FUNCTION get_potential_buddies(
    target_user_id INTEGER,
    min_interactions INTEGER DEFAULT 2,
    min_manner_score DECIMAL DEFAULT 4.0
) RETURNS TABLE(
    user_id INTEGER,
    username VARCHAR,
    display_name VARCHAR,
    manner_score DECIMAL,
    interaction_count INTEGER,
    common_categories TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        u.id,
        u.username,
        up.display_name,
        up.manner_score,
        COUNT(si.id) as interaction_count,
        ARRAY_AGG(DISTINCT s.category) as common_categories
    FROM users u
    JOIN user_profiles up ON up.user_id = u.id
    JOIN signal_interactions si ON (si.user1_id = u.id OR si.user2_id = u.id)
    JOIN signals s ON s.id = si.signal_id
    WHERE (si.user1_id = target_user_id OR si.user2_id = target_user_id)
      AND u.id != target_user_id
      AND up.manner_score >= min_manner_score
      AND u.id NOT IN (
          SELECT CASE 
              WHEN ub.user1_id = target_user_id THEN ub.user2_id
              WHEN ub.user2_id = target_user_id THEN ub.user1_id
          END
          FROM user_buddies ub 
          WHERE (ub.user1_id = target_user_id OR ub.user2_id = target_user_id)
            AND ub.status = 'active'
      )
    GROUP BY u.id, u.username, up.display_name, up.manner_score
    HAVING COUNT(si.id) >= min_interactions
    ORDER BY COUNT(si.id) DESC, up.manner_score DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;