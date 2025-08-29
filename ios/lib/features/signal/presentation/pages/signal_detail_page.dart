import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:signal_app/features/signal/domain/entities/signal.dart';
import 'package:signal_app/features/signal/presentation/cubit/signal_detail_cubit.dart';
import 'package:signal_app/features/signal/presentation/widgets/join_signal_bottom_sheet.dart';
import 'package:signal_app/features/signal/presentation/widgets/participant_list_widget.dart';
import 'package:signal_app/core/constants/app_constants.dart';

class SignalDetailPage extends StatefulWidget {
  final Signal signal;

  const SignalDetailPage({
    Key? key,
    required this.signal,
  }) : super(key: key);

  @override
  State<SignalDetailPage> createState() => _SignalDetailPageState();
}

class _SignalDetailPageState extends State<SignalDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSignalDetails();
  }

  void _setupAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));

    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOut,
    ));

    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOut,
    ));

    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _contentAnimationController.forward();
    });
  }

  void _loadSignalDetails() {
    context.read<SignalDetailCubit>().loadSignalDetail(widget.signal.id);
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _contentSlideAnimation,
              child: FadeTransition(
                opacity: _contentFadeAnimation,
                child: Column(
                  children: [
                    _buildSignalHeader(),
                    _buildHostSection(),
                    _buildSignalDetails(),
                    _buildLocationSection(),
                    _buildParticipantsSection(),
                    const SizedBox(height: 100), // Bottom padding for FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: FadeTransition(
          opacity: _headerAnimation,
          child: Text(
            widget.signal.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text('공유하기'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report, size: 20),
                  SizedBox(width: 8),
                  Text('신고하기'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignalHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCategoryChip(),
              const Spacer(),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.signal.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.signal.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip() {
    final categoryInfo = _getCategoryInfo(widget.signal.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: categoryInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryInfo['color'].withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            categoryInfo['icon'],
            size: 16,
            color: categoryInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            categoryInfo['name'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: categoryInfo['color'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final statusInfo = _getStatusInfo();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusInfo['color'].withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusInfo['icon'],
            size: 16,
            color: statusInfo['color'],
          ),
          const SizedBox(width: 4),
          Text(
            statusInfo['text'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusInfo['color'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: widget.signal.creator.profileImageUrl != null
                ? NetworkImage(widget.signal.creator.profileImageUrl!)
                : null,
            child: widget.signal.creator.profileImageUrl == null
                ? Text(
                    widget.signal.creator.nickname[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.signal.creator.nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '매너점수 ${widget.signal.creator.mannerScore.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showHostProfile,
            icon: const Icon(Icons.info_outline),
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSignalDetails() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '모임 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailItem(
            Icons.schedule,
            '모임 시간',
            _formatDateTime(widget.signal.scheduledAt),
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            Icons.people,
            '참여 인원',
            '${widget.signal.currentParticipants}/${widget.signal.maxParticipants}명',
          ),
          if (widget.signal.minAge > 0 || widget.signal.maxAge > 0) ...[
            const SizedBox(height: 12),
            _buildDetailItem(
              Icons.cake,
              '연령대',
              '${widget.signal.minAge}세 ~ ${widget.signal.maxAge}세',
            ),
          ],
          if (widget.signal.genderPreference != 'any') ...[
            const SizedBox(height: 12),
            _buildDetailItem(
              Icons.person,
              '성별',
              widget.signal.genderPreference == 'male' ? '남성만' : '여성만',
            ),
          ],
          const SizedBox(height: 12),
          _buildDetailItem(
            Icons.how_to_reg,
            '참여 방식',
            widget.signal.requiresApproval ? '승인 필요' : '바로 참여',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  '만날 장소',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openInMaps,
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('길찾기', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.signal.latitude, widget.signal.longitude),
                  zoom: 16.0,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('signal_location'),
                    position: LatLng(widget.signal.latitude, widget.signal.longitude),
                    infoWindow: InfoWindow(
                      title: widget.signal.title,
                      snippet: widget.signal.address,
                    ),
                  ),
                },
                zoomControlsEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                onTap: (_) => _openInMaps(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.signal.address,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '참여자 (${widget.signal.currentParticipants}/${widget.signal.maxParticipants})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BlocBuilder<SignalDetailCubit, SignalDetailState>(
            builder: (context, state) {
              if (state.isLoadingParticipants) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state.participants.isEmpty) {
                return const Text('참여자가 없습니다.');
              }

              return ParticipantListWidget(
                participants: state.participants,
                isCreator: state.isCreator,
                onParticipantTap: _showParticipantProfile,
                onApproveParticipant: _approveParticipant,
                onRejectParticipant: _rejectParticipant,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return BlocBuilder<SignalDetailCubit, SignalDetailState>(
      builder: (context, state) {
        if (state.isLoading) {
          return FloatingActionButton.extended(
            onPressed: null,
            label: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (state.isCreator) {
          return FloatingActionButton.extended(
            onPressed: _showCreatorMenu,
            icon: const Icon(Icons.settings),
            label: const Text('시그널 관리'),
            backgroundColor: Colors.orange,
          );
        }

        if (state.userParticipationStatus == 'approved') {
          return FloatingActionButton.extended(
            onPressed: _openChatRoom,
            icon: const Icon(Icons.chat),
            label: const Text('채팅방 입장'),
            backgroundColor: Colors.green,
          );
        }

        if (state.userParticipationStatus == 'pending') {
          return FloatingActionButton.extended(
            onPressed: _cancelJoinRequest,
            icon: const Icon(Icons.cancel),
            label: const Text('참여 요청 취소'),
            backgroundColor: Colors.grey,
          );
        }

        if (state.userParticipationStatus == 'rejected') {
          return FloatingActionButton.extended(
            onPressed: null,
            icon: const Icon(Icons.block),
            label: const Text('참여 거부됨'),
            backgroundColor: Colors.red,
          );
        }

        if (widget.signal.currentParticipants >= widget.signal.maxParticipants) {
          return FloatingActionButton.extended(
            onPressed: null,
            icon: const Icon(Icons.group),
            label: const Text('모집 완료'),
            backgroundColor: Colors.grey,
          );
        }

        return FloatingActionButton.extended(
          onPressed: _showJoinBottomSheet,
          icon: const Icon(Icons.add),
          label: const Text('참여 요청'),
          backgroundColor: Theme.of(context).primaryColor,
        );
      },
    );
  }

  Map<String, dynamic> _getCategoryInfo(String category) {
    final categories = {
      'sports': {'name': '운동', 'icon': Icons.sports_soccer, 'color': Colors.green},
      'food': {'name': '맛집', 'icon': Icons.restaurant, 'color': Colors.orange},
      'study': {'name': '스터디', 'icon': Icons.school, 'color': Colors.blue},
      'culture': {'name': '문화', 'icon': Icons.palette, 'color': Colors.purple},
      'travel': {'name': '여행', 'icon': Icons.flight_takeoff, 'color': Colors.cyan},
      'hobby': {'name': '취미', 'icon': Icons.palette, 'color': Colors.pink},
      'business': {'name': '비즈니스', 'icon': Icons.business_center, 'color': Colors.grey},
      'other': {'name': '기타', 'icon': Icons.more_horiz, 'color': Colors.grey},
    };
    return categories[category] ?? categories['other']!;
  }

  Map<String, dynamic> _getStatusInfo() {
    if (widget.signal.status == 'completed') {
      return {
        'text': '모임 완료',
        'icon': Icons.check_circle,
        'color': Colors.green,
      };
    } else if (widget.signal.currentParticipants >= widget.signal.maxParticipants) {
      return {
        'text': '모집 완료',
        'icon': Icons.group,
        'color': Colors.blue,
      };
    } else {
      return {
        'text': '모집 중',
        'icon': Icons.access_time,
        'color': Colors.orange,
      };
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 후 • ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 후';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 후';
    } else {
      return '곧 시작';
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'share':
        _shareSignal();
        break;
      case 'report':
        _reportSignal();
        break;
    }
  }

  void _shareSignal() {
    // Share functionality implementation
  }

  void _reportSignal() {
    // Report functionality implementation
  }

  void _showHostProfile() {
    // Show host profile modal
  }

  void _openInMaps() {
    // Open location in maps app
  }

  void _showParticipantProfile(String userId) {
    // Show participant profile
  }

  void _approveParticipant(String participantId) {
    context.read<SignalDetailCubit>().approveParticipant(participantId);
  }

  void _rejectParticipant(String participantId) {
    context.read<SignalDetailCubit>().rejectParticipant(participantId);
  }

  void _showCreatorMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('시그널 수정'),
              onTap: _editSignal,
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('시그널 삭제', style: TextStyle(color: Colors.red)),
              onTap: _deleteSignal,
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('모임 완료'),
              onTap: _completeSignal,
            ),
          ],
        ),
      ),
    );
  }

  void _openChatRoom() {
    // Navigate to chat room
  }

  void _cancelJoinRequest() {
    context.read<SignalDetailCubit>().cancelJoinRequest();
  }

  void _showJoinBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => JoinSignalBottomSheet(
        signal: widget.signal,
        onJoinRequested: (message) {
          context.read<SignalDetailCubit>().joinSignal(message);
        },
      ),
    );
  }

  void _editSignal() {
    Navigator.pop(context);
    // Navigate to edit signal page
  }

  void _deleteSignal() {
    Navigator.pop(context);
    context.read<SignalDetailCubit>().deleteSignal();
  }

  void _completeSignal() {
    Navigator.pop(context);
    context.read<SignalDetailCubit>().completeSignal();
  }
}