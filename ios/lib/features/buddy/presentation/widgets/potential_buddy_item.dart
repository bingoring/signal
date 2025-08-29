import 'package:flutter/material.dart';

import '../../data/models/buddy_model.dart';

class PotentialBuddyItem extends StatelessWidget {
  final PotentialBuddyModel candidate;
  final VoidCallback onAddBuddy;

  const PotentialBuddyItem({
    super.key,
    required this.candidate,
    required this.onAddBuddy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.primaryColor,
                  child: Text(
                    candidate.displayedName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.displayedName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '매너 ${candidate.mannerScore.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.handshake,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '상호작용 ${candidate.interactionCount}회',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (candidate.commonCategories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '공통 관심사',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: candidate.commonCategories.map((category) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _getCategoryName(category),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ),
            ],

            if (candidate.compatibilityScore != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.red[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '예상 궁합: ${candidate.compatibilityScore!.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 단골 추가 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddBuddy,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('단골로 추가'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String category) {
    // 카테고리 매핑 (실제 시그널 카테고리에 따라 조정)
    switch (category.toLowerCase()) {
      case 'sports':
        return '스포츠';
      case 'food':
        return '맛집';
      case 'culture':
        return '문화';
      case 'study':
        return '스터디';
      case 'hobby':
        return '취미';
      case 'travel':
        return '여행';
      case 'shopping':
        return '쇼핑';
      case 'entertainment':
        return '엔터테인먼트';
      default:
        return category;
    }
  }
}