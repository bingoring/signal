import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/signal_model.dart';
import '../cubit/signal_map_cubit.dart';

class SignalBottomSheet extends StatelessWidget {
  final Signal signal;

  const SignalBottomSheet({
    super.key,
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시그널 헤더
                  _buildHeader(),
                  
                  const SizedBox(height: 16),
                  
                  // 시그널 정보
                  _buildSignalInfo(context),
                  
                  const SizedBox(height: 16),
                  
                  // 위치 정보
                  _buildLocationInfo(context),
                  
                  const SizedBox(height: 16),
                  
                  // 설명
                  if (signal.description?.isNotEmpty == true) ...[
                    _buildDescription(),
                    const SizedBox(height: 16),
                  ],
                  
                  // 참여자 정보
                  _buildParticipantsInfo(context),
                  
                  const SizedBox(height: 20),
                  
                  // 액션 버튼들
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 아이콘
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCategoryColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(),
            color: _getCategoryColor(),
            size: 24,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // 제목 및 기본 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                signal.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  Text(
                    '${signal.currentParticipants}/${signal.maxParticipants}명',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 거리 표시
        if (signal.distance != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDistance(signal.distance!),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSignalInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.schedule,
            '예정 시간',
            _formatDateTime(signal.scheduledAt),
          ),
          
          const Divider(height: 20),
          
          _buildInfoRow(
            Icons.people,
            '참여자',
            '${signal.currentParticipants}/${signal.maxParticipants}명',
          ),
          
          if (signal.minAge != null && signal.maxAge != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              Icons.cake,
              '연령대',
              '${signal.minAge}세 - ${signal.maxAge}세',
            ),
          ],
          
          if (signal.genderPreference != null && signal.genderPreference != 'any') ...[
            const Divider(height: 20),
            _buildInfoRow(
              Icons.person,
              '성별',
              signal.genderPreference == 'male' ? '남성만' : '여성만',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red[400], size: 20),
              const SizedBox(width: 8),
              const Text(
                '만날 장소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (signal.placeName?.isNotEmpty == true)
            Text(
              signal.placeName!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          
          if (signal.address?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              signal.address!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // 길찾기 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openDirections(context),
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('길찾기'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상세 설명',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          signal.description!,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '참여자',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const Spacer(),
            
            if (signal.participants?.isNotEmpty == true)
              TextButton(
                onPressed: () => _showParticipantsList(context),
                child: const Text('전체 보기'),
              ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // 참여자 아바타들
        if (signal.participants?.isNotEmpty == true)
          _buildParticipantAvatars()
        else
          Text(
            '아직 참여자가 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildParticipantAvatars() {
    final participants = signal.participants!;
    const maxVisibleCount = 5;
    
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          ...participants
              .take(maxVisibleCount)
              .toList()
              .asMap()
              .entries
              .map((entry) {
            final index = entry.key;
            final participant = entry.value;
            
            return Positioned(
              left: index * 25.0,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                child: Text(
                  participant.user?.profile?.displayName?.substring(0, 1) ?? '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
          
          if (participants.length > maxVisibleCount)
            Positioned(
              left: maxVisibleCount * 25.0,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                child: Text(
                  '+${participants.length - maxVisibleCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isCreator = false; // TODO: 실제 사용자 확인 로직
    final isParticipant = false; // TODO: 실제 참여 상태 확인 로직
    final canJoin = signal.currentParticipants < signal.maxParticipants &&
                   signal.status == 'active';

    return Column(
      children: [
        if (!isCreator && !isParticipant && canJoin)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _joinSignal(context),
              icon: const Icon(Icons.add),
              label: const Text('참여하기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else if (!isCreator && !isParticipant && !canJoin)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.block),
              label: Text(signal.status == 'full' ? '정원 마감' : '참여 불가'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        else if (isParticipant)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _leaveSignal(context),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('나가기'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openChat(context),
                  icon: const Icon(Icons.chat),
                  label: const Text('채팅'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        
        const SizedBox(height: 8),
        
        // 상세 정보 및 공유
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _showSignalDetail(context),
                icon: const Icon(Icons.info_outline),
                label: const Text('상세 정보'),
              ),
            ),
            
            Expanded(
              child: TextButton.icon(
                onPressed: () => _shareSignal(context),
                icon: const Icon(Icons.share),
                label: const Text('공유하기'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods
  Color _getCategoryColor() {
    // TODO: 카테고리별 색상 정의
    return Colors.blue;
  }

  IconData _getCategoryIcon() {
    // TODO: 카테고리별 아이콘 정의
    return Icons.local_activity;
  }

  Color _getStatusColor() {
    switch (signal.status) {
      case 'active':
        return Colors.green;
      case 'full':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (signal.status) {
      case 'active':
        return '모집 중';
      case 'full':
        return '정원 마감';
      case 'closed':
        return '마감됨';
      default:
        return '알 수 없음';
    }
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // TODO: 적절한 날짜 포맷 구현
    return '${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Action methods
  void _joinSignal(BuildContext context) {
    context.read<SignalMapCubit>().joinSignal(signal.id);
    Navigator.pop(context);
  }

  void _leaveSignal(BuildContext context) {
    context.read<SignalMapCubit>().leaveSignal(signal.id);
    Navigator.pop(context);
  }

  void _openDirections(BuildContext context) {
    // TODO: 지도 앱으로 길찾기 열기
  }

  void _showParticipantsList(BuildContext context) {
    // TODO: 참여자 목록 모달 표시
  }

  void _openChat(BuildContext context) {
    // TODO: 채팅방으로 이동
  }

  void _showSignalDetail(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/signal/detail',
      arguments: {'signalId': signal.id},
    );
  }

  void _shareSignal(BuildContext context) {
    // TODO: 시그널 공유 기능
  }
}