import 'package:flutter/material.dart';
import 'chat_theme.dart';

class InstagramStyleAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String signalTitle;
  final List<String> participantAvatars;
  final SignalStatus status;
  final int onlineCount;
  final VoidCallback? onInfoPressed;
  final VoidCallback? onMenuPressed;

  const InstagramStyleAppBar({
    Key? key,
    required this.signalTitle,
    required this.participantAvatars,
    required this.status,
    this.onlineCount = 0,
    this.onInfoPressed,
    this.onMenuPressed,
  }) : super(key: key);

  @override
  State<InstagramStyleAppBar> createState() => _InstagramStyleAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);
}

class _InstagramStyleAppBarState extends State<InstagramStyleAppBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case SignalStatus.active:
        return ChatColors.online;
      case SignalStatus.meeting:
        return ChatColors.accent;
      case SignalStatus.completed:
        return ChatColors.primary;
      case SignalStatus.expired:
      case SignalStatus.closed:
        return ChatColors.offline;
    }
  }

  String _getStatusText() {
    switch (widget.status) {
      case SignalStatus.active:
        return '활성 중';
      case SignalStatus.meeting:
        return '모임 진행 중';
      case SignalStatus.completed:
        return '모임 완료';
      case SignalStatus.expired:
        return '만료됨';
      case SignalStatus.closed:
        return '종료됨';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ChatColors.surface,
        boxShadow: ChatShadows.card,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ChatDimensions.paddingMD,
            vertical: ChatDimensions.paddingSM,
          ),
          child: Row(
            children: [
              // 뒤로가기 버튼
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: ChatColors.textPrimary,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              
              const SizedBox(width: ChatDimensions.paddingSM),
              
              // 참여자 프로필 원형 배열
              _buildParticipantProfiles(),
              
              const SizedBox(width: ChatDimensions.paddingMD),
              
              // 제목 및 상태 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.signalTitle,
                      style: ChatTextStyles.appBarTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // 상태 인디케이터
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: widget.status == SignalStatus.meeting 
                                ? _pulseAnimation.value 
                                : 1.0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: ChatDimensions.paddingSM),
                        Text(
                          _getStatusText(),
                          style: ChatTextStyles.appBarSubtitle.copyWith(
                            color: _getStatusColor(),
                          ),
                        ),
                        if (widget.onlineCount > 0) ...[
                          const SizedBox(width: ChatDimensions.paddingSM),
                          Text(
                            '• ${widget.onlineCount}명 온라인',
                            style: ChatTextStyles.appBarSubtitle,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // 액션 버튼들
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onInfoPressed != null)
                    IconButton(
                      onPressed: widget.onInfoPressed,
                      icon: const Icon(
                        Icons.info_outline,
                        color: ChatColors.textSecondary,
                        size: 22,
                      ),
                      padding: const EdgeInsets.all(ChatDimensions.paddingSM),
                      constraints: const BoxConstraints(),
                    ),
                  
                  if (widget.onMenuPressed != null)
                    IconButton(
                      onPressed: widget.onMenuPressed,
                      icon: const Icon(
                        Icons.more_vert,
                        color: ChatColors.textSecondary,
                        size: 22,
                      ),
                      padding: const EdgeInsets.all(ChatDimensions.paddingSM),
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantProfiles() {
    const int maxVisible = 4;
    final visibleAvatars = widget.participantAvatars.take(maxVisible).toList();
    final remainingCount = widget.participantAvatars.length - maxVisible;

    return SizedBox(
      height: ChatDimensions.avatarMD,
      child: Stack(
        children: [
          // 프로필 아바타들
          ...visibleAvatars.asMap().entries.map((entry) {
            final index = entry.key;
            final avatarUrl = entry.value;
            
            return Positioned(
              left: index * 20.0, // 20px씩 겹치게 배치
              child: _buildProfileAvatar(avatarUrl, index),
            );
          }),
          
          // +N 표시 (남은 참여자 수)
          if (remainingCount > 0)
            Positioned(
              left: visibleAvatars.length * 20.0,
              child: _buildRemainingCount(remainingCount),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String avatarUrl, int index) {
    return Container(
      width: ChatDimensions.avatarMD,
      height: ChatDimensions.avatarMD,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ChatColors.surface,
          width: 2,
        ),
        boxShadow: ChatShadows.card,
      ),
      child: CircleAvatar(
        radius: ChatDimensions.avatarMD / 2 - 2,
        backgroundColor: ChatColors.primary.withOpacity(0.1),
        backgroundImage: avatarUrl.isNotEmpty 
          ? NetworkImage(avatarUrl)
          : null,
        child: avatarUrl.isEmpty 
          ? Icon(
              Icons.person,
              color: ChatColors.primary,
              size: ChatDimensions.avatarMD / 2,
            )
          : null,
      ),
    );
  }

  Widget _buildRemainingCount(int count) {
    return Container(
      width: ChatDimensions.avatarMD,
      height: ChatDimensions.avatarMD,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ChatColors.textSecondary,
        border: Border.all(
          color: ChatColors.surface,
          width: 2,
        ),
        boxShadow: ChatShadows.card,
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum SignalStatus {
  active,
  meeting,
  completed,
  expired,
  closed,
}