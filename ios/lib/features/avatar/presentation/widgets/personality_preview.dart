import 'package:flutter/material.dart';

class PersonalityPreview extends StatelessWidget {
  final String? currentAvatar;
  final VoidCallback? onAnalysisRequested;

  const PersonalityPreview({
    super.key,
    this.currentAvatar,
    this.onAnalysisRequested,
  });

  @override
  Widget build(BuildContext context) {
    if (currentAvatar == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onAnalysisRequested,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.withOpacity(0.1),
              Colors.blue.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.purple.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // 현재 아바타
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  currentAvatar!,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 설명 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Colors.purple[600],
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '나의 아바타 성향',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '아바타 선택으로 알아보는 나의 개성',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // 화살표 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.purple[600],
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 개성 분석 카드 (상세 페이지용)
class PersonalityAnalysisCard extends StatelessWidget {
  final String personalityType;
  final String description;
  final List<String> traits;
  final Color? accentColor;

  const PersonalityAnalysisCard({
    super.key,
    required this.personalityType,
    required this.description,
    required this.traits,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Colors.purple;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 성향 타입
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  personalityType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.psychology_outlined,
                color: color,
                size: 24,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 설명
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          if (traits.isNotEmpty) ...[
            const SizedBox(height: 16),
            
            // 특성들
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: traits.map((trait) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  trait,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.shade700,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}