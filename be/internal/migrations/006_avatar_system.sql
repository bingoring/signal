-- Phase 2: 이모지 아바타 시스템
-- 목적: 프로필 사진 업로드를 완전히 대체하는 이모지 아바타 시스템 구축
-- 특징: 카테고리별 아바타, 사용자 선호도, 개성 분석, 검색 기능

-- 1. 아바타 카테고리 테이블
CREATE TABLE avatar_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    description VARCHAR(200),
    color CHAR(7) DEFAULT '#6B7280',  -- HEX color for category theme
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_avatar_categories_active (is_active, sort_order),
    INDEX idx_avatar_categories_name (name)
);

-- 2. 아바타 테이블
CREATE TABLE avatars (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    emoji VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(50) NOT NULL,
    description VARCHAR(100),
    keywords VARCHAR(200),  -- 검색용 키워드 (쉼표로 구분)
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,  -- 기본 추천 아바타
    usage_count INT DEFAULT 0,  -- 전체 사용 통계
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (category_id) REFERENCES avatar_categories(id) ON DELETE CASCADE,
    INDEX idx_avatars_category (category_id, is_active, sort_order),
    INDEX idx_avatars_emoji (emoji),
    INDEX idx_avatars_default (is_default, is_active),
    INDEX idx_avatars_usage (usage_count DESC),
    FULLTEXT INDEX idx_avatars_search (name, description, keywords)
);

-- 3. 사용자-아바타 관계 테이블 (즐겨찾기, 사용 기록)
CREATE TABLE user_avatars (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    avatar_id INT NOT NULL,
    is_favorite BOOLEAN DEFAULT FALSE,
    last_used TIMESTAMP NULL,
    usage_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY idx_user_avatar (user_id, avatar_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (avatar_id) REFERENCES avatars(id) ON DELETE CASCADE,
    INDEX idx_user_avatars_user_favorite (user_id, is_favorite),
    INDEX idx_user_avatars_user_recent (user_id, last_used DESC),
    INDEX idx_user_avatars_usage (user_id, usage_count DESC)
);

-- 4. 아바타 카테고리 초기 데이터
INSERT INTO avatar_categories (name, display_name, description, color, sort_order) VALUES
('emotions', '감정 표현', '기분과 감정을 나타내는 아바타', '#F59E0B', 1),
('activities', '활동 & 취미', '취미와 활동을 나타내는 아바타', '#10B981', 2),
('food', '음식', '음식과 요리 관련 아바타', '#EF4444', 3),
('travel', '여행 & 모험', '여행과 모험 관련 아바타', '#3B82F6', 4),
('nature', '자연 & 동물', '자연과 동물 관련 아바타', '#22C55E', 5),
('creative', '창작 & 예술', '창작과 예술 활동 아바타', '#8B5CF6', 6),
('sports', '스포츠', '스포츠와 운동 관련 아바타', '#F97316', 7),
('tech', '기술 & 게임', '기술과 게임 관련 아바타', '#6366F1', 8),
('lifestyle', '라이프스타일', '일상과 라이프스타일 아바타', '#EC4899', 9),
('symbols', '심볼 & 기타', '기타 상징과 심볼 아바타', '#64748B', 10);

-- 5. 아바타 초기 데이터

-- 감정 표현 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(1, '😊', '행복한', '밝고 긍정적인 에너지', '행복,기쁨,웃음,긍정,밝음', 1, TRUE),
(1, '😎', '쿨한', '자신감 넘치는 쿨한 매력', '쿨,자신감,멋진,여유,카리스마', 2, TRUE),
(1, '🤗', '따뜻한', '포근하고 친근한 느낌', '따뜻함,포옹,친근,다정,위로', 3, FALSE),
(1, '😄', '신나는', '에너지 넘치는 즐거움', '신남,에너지,활발,즐거움,열정', 4, FALSE),
(1, '🤔', '생각하는', '깊이 있는 사고형', '생각,고민,철학,지혜,분석', 5, FALSE),
(1, '😌', '평온한', '차분하고 안정된 마음', '평온,안정,차분,평화,여유', 6, FALSE),
(1, '🙃', '장난스러운', '유머러스하고 재미있는', '장난,유머,재미,익살,개성', 7, FALSE),
(1, '😇', '순수한', '맑고 깨끗한 마음', '순수,맑음,깨끗,천사,선량', 8, FALSE);

-- 활동 & 취미 카테고리  
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(2, '🎵', '음악러버', '음악을 사랑하는 사람', '음악,노래,멜로디,리듬,악기', 1, TRUE),
(2, '📚', '독서광', '책을 좋아하는 지식인', '독서,책,지식,학습,문학', 2, TRUE),
(2, '🎨', '예술가', '창작과 예술을 즐기는', '예술,창작,그림,디자인,미술', 3, FALSE),
(2, '📷', '사진작가', '순간을 포착하는 사진가', '사진,촬영,기록,추억,순간', 4, FALSE),
(2, '🎭', '공연러버', '연극과 공연 애호가', '연극,공연,배우,무대,예술', 5, FALSE),
(2, '🎮', '게이머', '게임을 즐기는 사람', '게임,플레이,엔터테인먼트,취미', 6, FALSE),
(2, '🎯', '목표지향', '목표 달성을 중시하는', '목표,성취,도전,집중,성공', 7, FALSE),
(2, '🎪', '엔터테이너', '재미와 즐거움을 주는', '엔터테인먼트,재미,서커스,공연', 8, FALSE);

-- 음식 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(3, '🍕', '피자러버', '피자를 사랑하는 미식가', '피자,음식,맛집,이탈리안,치즈', 1, TRUE),
(3, '🍜', '라면매니아', '라면과 국물 요리 애호가', '라면,국물,면,아시안,따뜻함', 2, FALSE),
(3, '🍰', '디저트러버', '달콤한 디저트 애호가', '디저트,케이크,달콤,베이킹,카페', 3, FALSE),
(3, '🍣', '스시러버', '일식과 스시 애호가', '스시,일식,생선,신선,정교', 4, FALSE),
(3, '🌮', '타코러버', '멕시칸 푸드 애호가', '타코,멕시칸,매콤,향신료,이국적', 5, FALSE),
(3, '🍔', '버거러버', '햄버거와 패스트푸드 팬', '햄버거,패스트푸드,간편,맛있는', 6, FALSE),
(3, '☕', '커피러버', '커피와 카페 문화 애호가', '커피,카페,원두,향,아로마', 7, FALSE),
(3, '🥗', '건강식', '건강한 식단을 추구하는', '샐러드,건강,채소,다이어트,웰빙', 8, FALSE);

-- 여행 & 모험 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(4, '✈️', '여행가', '세계를 여행하는 모험가', '여행,비행기,모험,세계,탐험', 1, TRUE),
(4, '🏔️', '등산가', '산과 자연을 정복하는', '등산,산,자연,도전,정상', 2, TRUE),
(4, '🌍', '세계탐험가', '지구 곳곳을 탐험하는', '세계,탐험,지구,문화,경험', 3, FALSE),
(4, '🗺️', '길잡이', '새로운 길을 찾는 가이드', '지도,길,방향,가이드,탐색', 4, FALSE),
(4, '🎒', '백패커', '자유로운 배낭여행자', '배낭,자유,여행,모험,경험', 5, FALSE),
(4, '🚀', '우주탐험가', '우주를 꿈꾸는 미래지향적', '우주,로켓,미래,탐험,꿈', 6, FALSE),
(4, '⛵', '항해자', '바다를 항해하는 모험가', '바다,항해,배,모험,자유', 7, FALSE),
(4, '🏕️', '캠핑러버', '자연 속 캠핑을 즐기는', '캠핑,자연,텐트,힐링,휴식', 8, FALSE);

-- 자연 & 동물 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(5, '🐱', '고양이', '자유롭고 독립적인 성격', '고양이,자유,독립,귀여움,애완동물', 1, TRUE),
(5, '🐶', '강아지', '충실하고 활발한 성격', '강아지,충실,활발,친근,애완동물', 2, TRUE),
(5, '🦋', '나비', '아름답고 변화를 추구하는', '나비,아름다움,변화,자유,우아함', 3, FALSE),
(5, '🌻', '해바라기', '밝고 긍정적인 에너지', '해바라기,밝음,긍정,태양,희망', 4, FALSE),
(5, '🌙', '달', '신비롭고 감성적인', '달,신비,밤,감성,로맨틱', 5, FALSE),
(5, '⭐', '별', '꿈과 희망을 상징하는', '별,꿈,희망,빛,우주', 6, FALSE),
(5, '🌈', '무지개', '다채롭고 희망적인', '무지개,다양성,희망,색깔,아름다움', 7, FALSE),
(5, '🦉', '올빼미', '지혜롭고 밤형인간', '올빼미,지혜,밤,조용,사색', 8, FALSE);

-- 창작 & 예술 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(6, '🎨', '화가', '색채와 형태로 표현하는', '그림,미술,창작,예술,색채', 1, TRUE),
(6, '✍️', '작가', '글로 세상을 표현하는', '글쓰기,작가,문학,창작,이야기', 2, FALSE),
(6, '🎬', '영화감독', '영상으로 이야기를 만드는', '영화,감독,영상,스토리,창작', 3, FALSE),
(6, '🎤', '가수', '목소리로 감동을 전하는', '노래,음성,가수,감정,표현', 4, FALSE),
(6, '🎹', '음악가', '선율로 마음을 움직이는', '음악,악기,선율,작곡,연주', 5, FALSE),
(6, '💃', '댄서', '몸짓으로 표현하는 예술가', '춤,동작,리듬,표현,예술', 6, FALSE),
(6, '🖼️', '큐레이터', '예술 작품을 기획하는', '큐레이터,기획,전시,예술,문화', 7, FALSE),
(6, '🎪', '서커스', '독특하고 화려한 퍼포먼스', '서커스,퍼포먼스,독특,화려', 8, FALSE);

-- 스포츠 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(7, '⚽', '축구선수', '축구를 사랑하는 스포츠맨', '축구,스포츠,팀워크,운동,경기', 1, TRUE),
(7, '🏃', '러너', '달리기를 즐기는 건강인', '러닝,달리기,건강,지구력,운동', 2, TRUE),
(7, '🏊', '수영선수', '물에서 자유로운 사람', '수영,물,자유,건강,스포츠', 3, FALSE),
(7, '🚴', '자전거', '자전거로 세상을 누비는', '자전거,사이클,여행,환경,건강', 4, FALSE),
(7, '🏀', '농구선수', '농구의 역동성을 즐기는', '농구,점프,역동,팀워크,스포츠', 5, FALSE),
(7, '🎾', '테니스', '테니스의 우아함을 추구', '테니스,우아함,정확성,스포츠', 6, FALSE),
(7, '🥋', '무술가', '정신력과 육체의 조화', '무술,정신,훈련,절제,강함', 7, FALSE),
(7, '⛷️', '스키어', '설산을 자유롭게 활강', '스키,눈,자유,스릴,겨울', 8, FALSE);

-- 기술 & 게임 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(8, '💻', '프로그래머', '코드로 세상을 바꾸는', '프로그래밍,코딩,개발,기술,논리', 1, TRUE),
(8, '🎮', '게이머', '게임 세계의 주인공', '게임,플레이,엔터테인먼트,전략', 2, TRUE),
(8, '🔬', '과학자', '탐구하고 발견하는', '과학,연구,실험,발견,지식', 3, FALSE),
(8, '🛠️', '엔지니어', '기술로 문제를 해결하는', '엔지니어,기술,해결,창조,혁신', 4, FALSE),
(8, '📱', '테크러버', '최신 기술을 추구하는', '기술,혁신,트렌드,디지털,미래', 5, FALSE),
(8, '🤖', '로봇', '미래지향적 기술 애호가', '로봇,AI,미래,기술,자동화', 6, FALSE),
(8, '⚡', '에너지', '역동적이고 혁신적인', '에너지,전기,역동,혁신,강력', 7, FALSE),
(8, '🔋', '지속가능', '효율과 지속성을 추구', '배터리,지속가능,효율,환경,미래', 8, FALSE);

-- 라이프스타일 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(9, '🧘', '명상가', '내면의 평화를 추구하는', '명상,평화,요가,힐링,정신', 1, FALSE),
(9, '💄', '뷰티러버', '아름다움을 추구하는', '뷰티,화장,패션,아름다움,스타일', 2, FALSE),
(9, '👗', '패셔니스타', '스타일과 트렌드를 주도', '패션,스타일,트렌드,옷,센스', 3, FALSE),
(9, '🏡', '홈카페', '집에서의 여유를 즐기는', '집,카페,여유,힐링,편안함', 4, FALSE),
(9, '🌱', '친환경', '지구를 생각하는 생활인', '환경,친환경,지속가능,자연,보호', 5, FALSE),
(9, '💎', '럭셔리', '고급스러운 라이프스타일', '럭셔리,고급,품격,우아함,세련', 6, FALSE),
(9, '🎀', '큐트', '귀엽고 사랑스러운', '귀여움,사랑스러움,깜찍,애교,순수', 7, FALSE),
(9, '✨', '반짝반짝', '특별하고 빛나는', '반짝임,특별,빛,매직,아름다움', 8, FALSE);

-- 심볼 & 기타 카테고리
INSERT INTO avatars (category_id, emoji, name, description, keywords, sort_order, is_default) VALUES
(10, '🔥', '열정', '뜨거운 열정을 가진', '열정,불,뜨거움,에너지,강렬', 1, FALSE),
(10, '💫', '유성', '꿈을 향해 달려가는', '유성,꿈,소원,빠름,희망', 2, FALSE),
(10, '🎯', '정확성', '목표를 정확히 맞히는', '정확,목표,집중,성취,성공', 3, FALSE),
(10, '🌟', '스타', '빛나는 존재감을 가진', '스타,빛,존재감,특별,인기', 4, FALSE),
(10, '💝', '선물', '남에게 기쁨을 주는', '선물,기쁨,나눔,감사,사랑', 5, FALSE),
(10, '🎊', '축하', '기쁨과 축하를 좋아하는', '축하,기쁨,파티,즐거움,화려', 6, FALSE),
(10, '🔮', '신비', '신비롭고 직관적인', '신비,직감,마법,특별,신기함', 7, FALSE),
(10, '💯', '완벽주의', '최고를 추구하는', '완벽,최고,100점,우수,품질', 8, FALSE);

-- 6. 비즈니스 로직은 애플리케이션 레벨에서 처리
-- 아바타 사용 통계 업데이트: Go 백엔드 AvatarService.SetUserAvatar()에서 처리
-- 매너온도 업데이트: 비동기 워커에서 주기적으로 일괄 처리
-- 이유: 트리거는 데이터 일관성 문제와 디버깅 어려움 야기

-- 8. 인덱스 추가 최적화
CREATE INDEX idx_avatars_active_category ON avatars(is_active, category_id, sort_order);
CREATE INDEX idx_user_avatars_stats ON user_avatars(user_id, usage_count DESC, last_used DESC);

-- 9. 뷰 생성: 인기 아바타 통계
CREATE VIEW popular_avatars AS
SELECT 
    a.id,
    a.emoji,
    a.name,
    ac.display_name as category_name,
    a.usage_count,
    COUNT(DISTINCT ua.user_id) as unique_users,
    ROUND(COUNT(DISTINCT ua.user_id) * 100.0 / (
        SELECT COUNT(DISTINCT user_id) FROM user_profiles WHERE avatar IS NOT NULL
    ), 2) as popularity_percentage
FROM avatars a
JOIN avatar_categories ac ON a.category_id = ac.id
LEFT JOIN user_avatars ua ON a.id = ua.avatar_id
WHERE a.is_active = TRUE
GROUP BY a.id, a.emoji, a.name, ac.display_name, a.usage_count
ORDER BY unique_users DESC, a.usage_count DESC;

-- 10. 마이그레이션 로그
INSERT INTO migration_logs (migration_name, executed_at, status, description) 
VALUES (
    '006_avatar_system',
    CURRENT_TIMESTAMP,
    'SUCCESS',
    'Phase 2: 이모지 아바타 시스템 구축 완료 - 카테고리, 아바타, 사용자 관계, 검색 기능, 통계 시스템'
);

-- 완료 확인 쿼리
SELECT 
    'Avatar System Setup Complete!' as message,
    (SELECT COUNT(*) FROM avatar_categories WHERE is_active = TRUE) as total_categories,
    (SELECT COUNT(*) FROM avatars WHERE is_active = TRUE) as total_avatars,
    (SELECT COUNT(*) FROM avatars WHERE is_default = TRUE) as default_avatars;