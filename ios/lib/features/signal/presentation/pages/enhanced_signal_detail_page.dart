import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/signal.dart';
import '../cubit/signal_detail_cubit.dart';
import '../cubit/signal_detail_state.dart';
import '../cubit/join_request_cubit.dart';
import '../widgets/enhanced_join_request_bottom_sheet.dart';
import '../widgets/enhanced_category_selector.dart';

class EnhancedSignalDetailPage extends StatefulWidget {
  final Signal signal;
  final int? currentUserId;

  const EnhancedSignalDetailPage({
    super.key,
    required this.signal,
    this.currentUserId,
  });

  @override
  State<EnhancedSignalDetailPage> createState() => _EnhancedSignalDetailPageState();
}

class _EnhancedSignalDetailPageState extends State<EnhancedSignalDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupMap();
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

    _headerFadeAnimation = Tween<double>(
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
      if (mounted) {
        _contentAnimationController.forward();
      }
    });
  }

  void _setupMap() {
    _markers.add(
      Marker(
        markerId: const MarkerId('signal_location'),
        position: LatLng(widget.signal.latitude, widget.signal.longitude),
        infoWindow: InfoWindow(
          title: widget.signal.placeName ?? '만날 장소',
          snippet: widget.signal.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
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
    final theme = Theme.of(context);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(theme),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _contentSlideAnimation,
              child: FadeTransition(
                opacity: _contentFadeAnimation,
                child: Column(
                  children: [
                    _buildSignalHeader(theme),
                    _buildHostSection(theme),
                    _buildSignalDetails(theme),
                    _buildLocationSection(theme),
                    _buildParticipantsSection(theme),
                    const SizedBox(height: 100), // Bottom padding for FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildActionButton(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        title: FadeTransition(
          opacity: _headerFadeAnimation,
          child: Text(
            widget.signal.title,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Status bar padding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.signal.category.categoryIcon,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.signal.category.displayName,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onPrimary,
          ),
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

  Widget _buildSignalHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.signal.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(widget.signal.status).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(widget.signal.status),
                      size: 16,
                      color: _getStatusColor(widget.signal.status),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(widget.signal.status),
                      style: TextStyle(
                        color: _getStatusColor(widget.signal.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(widget.signal.scheduledAt),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            widget.signal.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          if (widget.signal.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.signal.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHostSection(ThemeData theme) {
    final creator = widget.signal.creator;
    if (creator == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: creator.profile?.profileImageUrl != null
                ? NetworkImage(creator.profile!.profileImageUrl!)
                : null,
            child: creator.profile?.profileImageUrl == null
                ? Text(
                    creator.profile?.displayName?.substring(0, 1).toUpperCase() ?? 
                    creator.username?.substring(0, 1).toUpperCase() ?? 'H',
                    style: theme.textTheme.titleMedium?.copyWith(
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
                Row(
                  children: [
                    Text(
                      creator.profile?.displayName ?? creator.username ?? '호스트',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '호스트',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (creator.profile != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${creator.profile!.age}세',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${creator.profile!.mannerScore.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${creator.profile!.totalRatings})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Navigate to host profile
            },
            icon: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalDetails(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '상세 정보',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Participant count
          _buildDetailRow(
            theme,
            Icons.people,
            '참여 인원',
            '${widget.signal.currentParticipants}/${widget.signal.maxParticipants}명',
            progress: widget.signal.currentParticipants / widget.signal.maxParticipants,
          ),
          
          // Age range
          if (widget.signal.minAge != null || widget.signal.maxAge != null)
            _buildDetailRow(
              theme,
              Icons.cake,
              '연령대',
              '${widget.signal.minAge ?? 0}세 ~ ${widget.signal.maxAge ?? 100}세',
            ),
          
          // Gender preference
          if (widget.signal.genderPreference != null)
            _buildDetailRow(
              theme,
              Icons.wc,
              '성별',
              _getGenderDisplayName(widget.signal.genderPreference!),
            ),
          
          // Join method
          _buildDetailRow(
            theme,
            widget.signal.requireApproval ? Icons.approval : Icons.flash_on,
            '참가 방식',
            widget.signal.requireApproval ? '승인 필요' : '즉시 참가',
          ),
          
          // Scheduled time
          _buildDetailRow(
            theme,
            Icons.schedule,
            '시간',
            DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(widget.signal.scheduledAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    double? progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? Colors.red : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '만날 장소',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('길찾기'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Address
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.place,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.signal.placeName != null) ...[
                        Text(
                          widget.signal.placeName!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        widget.signal.address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Map
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.signal.latitude, widget.signal.longitude),
                  zoom: 16.0,
                ),
                markers: _markers,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '참여자',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.signal.currentParticipants}명',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Participants list
          BlocBuilder<SignalDetailCubit, SignalDetailState>(
            builder: (context, state) {
              if (state.status == SignalDetailStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              
              final participants = state.signal?.participants ?? widget.signal.participants ?? [];
              
              if (participants.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_add,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '아직 참여자가 없습니다',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '첫 번째 참여자가 되어보세요!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return Column(
                children: participants.map((participant) {
                  return _buildParticipantCard(theme, participant);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(ThemeData theme, SignalParticipant participant) {
    final user = participant.user;
    if (user == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: user.profile?.profileImageUrl != null
                ? NetworkImage(user.profile!.profileImageUrl!)
                : null,
            child: user.profile?.profileImageUrl == null
                ? Text(
                    user.profile?.displayName?.substring(0, 1).toUpperCase() ??
                    user.username?.substring(0, 1).toUpperCase() ?? 'U',
                    style: theme.textTheme.titleSmall?.copyWith(
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
                Row(
                  children: [
                    Text(
                      user.profile?.displayName ?? user.username ?? '사용자',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (participant.status == 'approved') ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: Colors.green,
                      ),
                    ],
                  ],
                ),
                if (user.profile != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${user.profile!.age}세',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            user.profile!.mannerScore.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getParticipantStatusColor(participant.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getParticipantStatusText(participant.status),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getParticipantStatusColor(participant.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    final isOwner = widget.currentUserId != null &&
                   widget.currentUserId == widget.signal.creatorId;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: isOwner
          ? _buildOwnerActions(theme)
          : _buildParticipantAction(theme),
    );
  }

  Widget _buildOwnerActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showJoinRequestBottomSheet,
            icon: const Icon(Icons.people),
            label: const Text('참가 신청서'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openChatRoom,
            icon: const Icon(Icons.chat),
            label: const Text('채팅방'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantAction(ThemeData theme) {
    final isFull = widget.signal.currentParticipants >= widget.signal.maxParticipants;
    final isExpired = widget.signal.scheduledAt.isBefore(DateTime.now());
    final isActive = widget.signal.status == 'active';
    
    String buttonText = '시그널 참가하기';
    Color? buttonColor = theme.colorScheme.primary;
    VoidCallback? onPressed = _showJoinRequestBottomSheet;
    
    if (!isActive) {
      buttonText = '참가할 수 없는 시그널';
      buttonColor = Colors.grey;
      onPressed = null;
    } else if (isExpired) {
      buttonText = '시간이 지난 시그널';
      buttonColor = Colors.grey;
      onPressed = null;
    } else if (isFull) {
      buttonText = '정원이 마감된 시그널';
      buttonColor = Colors.orange;
      onPressed = null;
    }
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: buttonColor == Colors.grey 
            ? Colors.white
            : theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        buttonText,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
    // TODO: Implement share functionality
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('공유 기능이 곧 제공될 예정입니다.'),
      ),
    );
  }

  void _reportSignal() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신고하기'),
        content: const Text('이 시그널을 신고하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('신고가 접수되었습니다.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('신고'),
          ),
        ],
      ),
    );
  }

  void _showJoinRequestBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider(
        create: (context) => JoinRequestCubit(
          apiService: context.read<SignalApiService>(),
        ),
        child: EnhancedJoinRequestBottomSheet(
          signal: widget.signal,
          isOwner: widget.currentUserId == widget.signal.creatorId,
          currentUserId: widget.currentUserId,
        ),
      ),
    ).then((_) {
      // Refresh signal details when bottom sheet closes
      _loadSignalDetails();
    });
  }

  void _openChatRoom() {
    HapticFeedback.lightImpact();
    // TODO: Navigate to chat room
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('채팅방 기능이 곧 제공될 예정입니다.'),
      ),
    );
  }

  Future<void> _openInMaps() async {
    HapticFeedback.lightImpact();
    final url = 'https://maps.google.com/?q=${widget.signal.latitude},${widget.signal.longitude}';
    
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('지도 앱을 열 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'full':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'full':
        return Icons.group;
      case 'closed':
        return Icons.lock;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '모집중';
      case 'full':
        return '정원마감';
      case 'closed':
        return '마감';
      case 'cancelled':
        return '취소됨';
      case 'completed':
        return '완료됨';
      default:
        return '알수없음';
    }
  }

  String _getGenderDisplayName(String preference) {
    switch (preference) {
      case 'male':
        return '남성만';
      case 'female':
        return '여성만';
      default:
        return '성별 무관';
    }
  }

  Color _getParticipantStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getParticipantStatusText(String status) {
    switch (status) {
      case 'approved':
        return '참가중';
      case 'pending':
        return '대기중';
      case 'rejected':
        return '거절됨';
      default:
        return '알수없음';
    }
  }
}