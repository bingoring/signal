import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_theme.dart';
import '../pages/chat_room_page.dart';

class QuickActionPanel extends StatefulWidget {
  final VoidCallback? onLocationShare;
  final VoidCallback? onImagePicker;
  final Function(QuickReplyType)? onQuickReply;
  final bool isVisible;

  const QuickActionPanel({
    Key? key,
    this.onLocationShare,
    this.onImagePicker,
    this.onQuickReply,
    this.isVisible = false,
  }) : super(key: key);

  @override
  State<QuickActionPanel> createState() => _QuickActionPanelState();
}

class _QuickActionPanelState extends State<QuickActionPanel>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: ChatDimensions.animationMedium,
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: ChatDimensions.animationFast,
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }

  @override
  void didUpdateWidget(QuickActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
        _fadeController.forward();
      } else {
        _slideController.reverse();
        _fadeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleActionTap(VoidCallback? callback) {
    HapticFeedback.selectionClick();
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(ChatDimensions.paddingMD),
        decoration: const BoxDecoration(
          color: ChatColors.surface,
          boxShadow: ChatShadows.popup,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick Reply Actions
              _buildQuickReplySection(),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ChatDimensions.paddingSM),
                child: Divider(color: ChatColors.divider),
              ),
              
              // Media Actions
              _buildMediaActionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReplySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: ChatDimensions.paddingSM),
          child: Text(
            '빠른 응답',
            style: ChatTextStyles.systemText.copyWith(
              fontWeight: FontWeight.w600,
              color: ChatColors.textPrimary,
            ),
          ),
        ),
        
        Wrap(
          spacing: ChatDimensions.paddingSM,
          runSpacing: ChatDimensions.paddingSM,
          children: [
            _buildQuickReplyChip(
              QuickReplyType.arrived,
              '도착했어요',
              Icons.location_on,
              ChatColors.online,
            ),
            _buildQuickReplyChip(
              QuickReplyType.onWay,
              '가는 중이에요',
              Icons.directions_run,
              ChatColors.primary,
            ),
            _buildQuickReplyChip(
              QuickReplyType.late5min,
              '5분 늦을게요',
              Icons.access_time,
              ChatColors.away,
            ),
            _buildQuickReplyChip(
              QuickReplyType.late10min,
              '10분 늦을게요',
              Icons.access_time,
              ChatColors.away,
            ),
            _buildQuickReplyChip(
              QuickReplyType.late15min,
              '15분 늦을게요',
              Icons.access_time,
              ChatColors.away,
            ),
            _buildQuickReplyChip(
              QuickReplyType.cancel,
              '취소할게요',
              Icons.cancel,
              ChatColors.accent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickReplyChip(
    QuickReplyType type,
    String text,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => _handleQuickReply(type),
      child: AnimatedScale(
        scale: 1.0,
        duration: ChatDimensions.animationFast,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ChatDimensions.paddingMD,
            vertical: ChatDimensions.paddingSM,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ChatDimensions.radiusXL),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: ChatDimensions.paddingSM),
              Text(
                text,
                style: ChatTextStyles.systemText.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: ChatDimensions.paddingSM),
          child: Text(
            '미디어 및 위치',
            style: ChatTextStyles.systemText.copyWith(
              fontWeight: FontWeight.w600,
              color: ChatColors.textPrimary,
            ),
          ),
        ),
        
        Row(
          children: [
            _buildMediaAction(
              '위치 공유',
              Icons.location_on,
              ChatColors.locationBackground,
              widget.onLocationShare,
            ),
            const SizedBox(width: ChatDimensions.paddingMD),
            _buildMediaAction(
              '사진',
              Icons.photo_camera,
              ChatColors.primary,
              widget.onImagePicker,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleActionTap(onTap),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: ChatDimensions.paddingMD,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ChatDimensions.radiusMD),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(ChatDimensions.paddingMD),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: ChatDimensions.paddingSM),
              Text(
                label,
                style: ChatTextStyles.systemText.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleQuickReply(QuickReplyType type) {
    HapticFeedback.selectionClick();
    widget.onQuickReply?.call(type);
  }
}

// Quick Action Floating Button
class QuickActionFloatingButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isExpanded;

  const QuickActionFloatingButton({
    Key? key,
    this.onPressed,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<QuickActionFloatingButton> createState() => _QuickActionFloatingButtonState();
}

class _QuickActionFloatingButtonState extends State<QuickActionFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _rotationController = AnimationController(
      duration: ChatDimensions.animationMedium,
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.375, // 45도 회전 (1/8 회전)
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(QuickActionFloatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _rotationController.forward();
      } else {
        _rotationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPressed?.call();
      },
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159, // Convert to radians
            child: Container(
              width: ChatDimensions.quickActionSize,
              height: ChatDimensions.quickActionSize,
              decoration: BoxDecoration(
                gradient: ChatColors.instagramGradient,
                shape: BoxShape.circle,
                boxShadow: ChatShadows.card,
              ),
              child: Center(
                child: Icon(
                  widget.isExpanded ? Icons.close : Icons.add,
                  color: Colors.white,
                  size: ChatDimensions.quickActionIconSize,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}