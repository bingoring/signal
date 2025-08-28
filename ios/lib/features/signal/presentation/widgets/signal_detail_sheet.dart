import 'package:flutter/material.dart';
import '../../data/models/signal_model.dart';

class SignalDetailSheet extends StatelessWidget {
  final SignalModel signal;

  const SignalDetailSheet({
    super.key,
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 시그널 제목과 카테고리
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getCategoryColor(signal.category),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  signal.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (signal.distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${signal.distance!.round()}m',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 제목
          Text(
            signal.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 설명
          Text(
            signal.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // 세부 정보
          _buildInfoRow(
            Icons.location_on,
            '위치',
            signal.address,
          ),
          _buildInfoRow(
            Icons.schedule,
            '시간',
            _formatDateTime(signal.scheduledAt),
          ),
          _buildInfoRow(
            Icons.people,
            '참여자',
            '${signal.currentParticipants}/${signal.maxParticipants}명',
          ),
          if (signal.creator.username != null)
            _buildInfoRow(
              Icons.person,
              '주최자',
              signal.creator.username!,
            ),

          const SizedBox(height: 24),

          // 참여 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: signal.currentParticipants >= signal.maxParticipants
                  ? null
                  : () => _joinSignal(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                signal.currentParticipants >= signal.maxParticipants
                    ? '정원 마감'
                    : signal.requireApproval
                        ? '참여 신청하기'
                        : '즉시 참여하기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '운동':
        return Colors.red;
      case '스터디':
        return Colors.blue;
      case '취미':
        return Colors.green;
      case '음식':
        return Colors.orange;
      case '문화':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 후';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 후';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _joinSignal(BuildContext context) {
    // TODO: 실제 시그널 참여 로직
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시그널 참여'),
        content: const Text('이 시그널에 참여하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('시그널 참여 신청이 완료되었습니다!'),
                ),
              );
            },
            child: const Text('참여'),
          ),
        ],
      ),
    );
  }
}