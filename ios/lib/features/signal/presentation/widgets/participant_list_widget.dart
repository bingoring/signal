import 'package:flutter/material.dart';
import 'package:signal_app/features/signal/domain/entities/signal_participant.dart';

class ParticipantListWidget extends StatefulWidget {
  final List<SignalParticipant> participants;
  final bool isCreator;
  final Function(String userId) onParticipantTap;
  final Function(String participantId) onApproveParticipant;
  final Function(String participantId) onRejectParticipant;

  const ParticipantListWidget({
    Key? key,
    required this.participants,
    required this.isCreator,
    required this.onParticipantTap,
    required this.onApproveParticipant,
    required this.onRejectParticipant,
  }) : super(key: key);

  @override
  State<ParticipantListWidget> createState() => _ParticipantListWidgetState();
}

class _ParticipantListWidgetState extends State<ParticipantListWidget>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late List<AnimationController> _itemControllers;
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _itemControllers = List.generate(
      widget.participants.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 400 + (index * 100)),
        vsync: this,
      ),
    );

    _slideAnimations = _itemControllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(-0.3, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));
    }).toList();

    _fadeAnimations = _itemControllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeIn,
      ));
    }).toList();

    // Staggered animation start
    for (int i = 0; i < _itemControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _itemControllers[i].forward();
        }
      });
    }

    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participants.isEmpty) {
      return _buildEmptyState();
    }

    final approvedParticipants = widget.participants
        .where((p) => p.status == ParticipantStatus.approved)
        .toList();
    final pendingParticipants = widget.participants
        .where((p) => p.status == ParticipantStatus.pending)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (approvedParticipants.isNotEmpty) ...[
          _buildSectionHeader('참여 중', approvedParticipants.length, Icons.check_circle, Colors.green),
          const SizedBox(height: 12),
          ...approvedParticipants.asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            return _buildParticipantItem(participant, index);
          }).toList(),
        ],
        if (pendingParticipants.isNotEmpty && widget.isCreator) ...[
          if (approvedParticipants.isNotEmpty) const SizedBox(height: 24),
          _buildSectionHeader('승인 대기', pendingParticipants.length, Icons.access_time, Colors.orange),
          const SizedBox(height: 12),
          ...pendingParticipants.asMap().entries.map((entry) {
            final index = entry.key + approvedParticipants.length;
            final participant = entry.value;
            return _buildParticipantItem(participant, index);
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 참여자가 없어요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '첫 번째 참여자가 되어보세요!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon, Color color) {
    return FadeTransition(
      opacity: _listAnimationController,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantItem(SignalParticipant participant, int index) {
    if (index >= _slideAnimations.length) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimations[index],
      child: FadeTransition(
        opacity: _fadeAnimations[index],
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildParticipantAvatar(participant),
              const SizedBox(width: 12),
              Expanded(
                child: _buildParticipantInfo(participant),
              ),
              if (widget.isCreator && participant.status == ParticipantStatus.pending)
                _buildActionButtons(participant),
              if (participant.status == ParticipantStatus.approved)
                _buildStatusChip(participant.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(SignalParticipant participant) {
    return GestureDetector(
      onTap: () => widget.onParticipantTap(participant.user.id),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: participant.user.profileImageUrl != null
                ? NetworkImage(participant.user.profileImageUrl!)
                : null,
            child: participant.user.profileImageUrl == null
                ? Text(
                    participant.user.nickname[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          if (participant.isHost)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.star,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantInfo(SignalParticipant participant) {
    return GestureDetector(
      onTap: () => widget.onParticipantTap(participant.user.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                participant.user.nickname,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (participant.isHost) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '주최자',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.star,
                size: 14,
                color: Colors.amber.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '매너점수 ${participant.user.mannerScore.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (participant.joinedAt != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatJoinTime(participant.joinedAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
          if (participant.message.isNotEmpty && widget.isCreator) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                participant.message,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(SignalParticipant participant) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.check,
          color: Colors.green,
          onPressed: () => _showApprovalDialog(participant, true),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.close,
          color: Colors.red,
          onPressed: () => _showApprovalDialog(participant, false),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusChip(ParticipantStatus status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case ParticipantStatus.approved:
        color = Colors.green;
        text = '참여중';
        icon = Icons.check_circle;
        break;
      case ParticipantStatus.pending:
        color = Colors.orange;
        text = '대기중';
        icon = Icons.access_time;
        break;
      case ParticipantStatus.rejected:
        color = Colors.red;
        text = '거부됨';
        icon = Icons.cancel;
        break;
      case ParticipantStatus.left:
        color = Colors.grey;
        text = '나감';
        icon = Icons.exit_to_app;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinTime(DateTime joinTime) {
    final now = DateTime.now();
    final difference = now.difference(joinTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  void _showApprovalDialog(SignalParticipant participant, bool isApproval) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          isApproval ? '참여 승인' : '참여 거부',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: participant.user.profileImageUrl != null
                      ? NetworkImage(participant.user.profileImageUrl!)
                      : null,
                  child: participant.user.profileImageUrl == null
                      ? Text(
                          participant.user.nickname[0].toUpperCase(),
                          style: const TextStyle(fontSize: 14),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  participant.user.nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isApproval
                  ? '${participant.user.nickname}님의 참여를 승인하시겠습니까?'
                  : '${participant.user.nickname}님의 참여를 거부하시겠습니까?',
            ),
            if (participant.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '참여 메시지:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      participant.message,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isApproval) {
                widget.onApproveParticipant(participant.id);
              } else {
                widget.onRejectParticipant(participant.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isApproval ? '승인' : '거부'),
          ),
        ],
      ),
    );
  }
}