import 'package:flutter/material.dart';

import '../../data/models/buddy_model.dart';

class BuddyListItem extends StatelessWidget {
  final BuddyModel buddy;
  final VoidCallback onTap;
  final VoidCallback onMessage;
  final VoidCallback onInvite;

  const BuddyListItem({
    super.key,
    required this.buddy,
    required this.onTap,
    required this.onMessage,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      buddy.displayName[0].toUpperCase(),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                buddy.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(),
                          ],
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
                              '매너 ${buddy.buddyMannerScore.toStringAsFixed(1)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.favorite,
                              size: 16,
                              color: Colors.red[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '궁합 ${buddy.compatibilityScore.toStringAsFixed(1)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '함께한 시그널: ${buddy.totalSignals}개',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '상호작용: ${buddy.interactionCount}회',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '마지막 활동: ${_formatLastInteraction()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.message, size: 20),
                            onPressed: onMessage,
                            tooltip: '메시지 보내기',
                            style: IconButton.styleFrom(
                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                              foregroundColor: theme.primaryColor,
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, size: 20),
                            onPressed: onInvite,
                            tooltip: '시그널 초대',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              foregroundColor: Colors.green,
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String text;

    switch (buddy.status) {
      case 'active':
        color = Colors.green;
        text = '활성';
        break;
      case 'paused':
        color = Colors.orange;
        text = '일시정지';
        break;
      case 'blocked':
        color = Colors.red;
        text = '차단됨';
        break;
      default:
        color = Colors.grey;
        text = buddy.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatLastInteraction() {
    final now = DateTime.now();
    final difference = now.difference(buddy.lastInteraction);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}개월 전';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}