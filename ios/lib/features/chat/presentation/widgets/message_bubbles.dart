import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_theme.dart';
import '../pages/chat_room_page.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _scaleController = AnimationController(
      duration: ChatDimensions.animationFast,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ChatDimensions.paddingMD,
        vertical: ChatDimensions.paddingSM,
      ),
      child: Row(
        mainAxisAlignment: widget.isMe 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe) _buildAvatar(),
          if (!widget.isMe) const SizedBox(width: ChatDimensions.paddingSM),
          
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isMe 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
              children: [
                if (!widget.isMe) _buildSenderName(),
                if (!widget.isMe) const SizedBox(height: 4),
                
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: GestureDetector(
                        onTapDown: _handleTapDown,
                        onTapUp: _handleTapUp,
                        onTapCancel: _handleTapCancel,
                        onLongPress: widget.onLongPress,
                        child: _buildMessageContent(),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 4),
                _buildMessageInfo(),
              ],
            ),
          ),
          
          if (widget.isMe) const SizedBox(width: ChatDimensions.paddingSM),
          if (widget.isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: ChatDimensions.avatarSM,
      height: ChatDimensions.avatarSM,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isMe 
          ? ChatColors.primary.withOpacity(0.1)
          : ChatColors.textSecondary.withOpacity(0.1),
      ),
      child: Center(
        child: Text(
          widget.message.senderName.isNotEmpty 
            ? widget.message.senderName[0].toUpperCase()
            : '?',
          style: TextStyle(
            color: widget.isMe ? ChatColors.primary : ChatColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(left: ChatDimensions.paddingMD),
      child: Text(
        widget.message.senderName,
        style: ChatTextStyles.timestampText.copyWith(
          fontWeight: FontWeight.w600,
          color: ChatColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (widget.message.type) {
      case MessageType.text:
        return _buildTextMessage();
      case MessageType.location:
        return LocationMessageCard(message: widget.message, isMe: widget.isMe);
      case MessageType.quickReply:
        return QuickReplyMessageChip(message: widget.message, isMe: widget.isMe);
      case MessageType.system:
        return _buildSystemMessage();
      case MessageType.countdown:
        return _buildCountdownMessage();
      case MessageType.status:
        return _buildStatusMessage();
      case MessageType.image:
        return _buildImageMessage();
    }
  }

  Widget _buildTextMessage() {
    return Container(
      padding: ChatDimensions.messagePadding,
      decoration: BoxDecoration(
        color: widget.isMe ? ChatColors.myMessage : ChatColors.otherMessage,
        borderRadius: _getMessageBorderRadius(),
        boxShadow: ChatShadows.card,
      ),
      child: Text(
        widget.message.content,
        style: ChatTextStyles.messageText.copyWith(
          color: widget.isMe ? ChatColors.textOnPrimary : ChatColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      padding: ChatDimensions.messagePadding,
      decoration: BoxDecoration(
        color: ChatColors.systemMessage,
        borderRadius: BorderRadius.circular(ChatDimensions.radiusMD),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: ChatColors.primary,
          ),
          const SizedBox(width: ChatDimensions.paddingSM),
          Flexible(
            child: Text(
              widget.message.content,
              style: ChatTextStyles.systemText.copyWith(
                color: ChatColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownMessage() {
    return Container(
      padding: ChatDimensions.messagePadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ChatColors.accent.withOpacity(0.1),
            ChatColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(ChatDimensions.radiusMD),
        border: Border.all(
          color: ChatColors.accent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 18,
            color: ChatColors.accent,
          ),
          const SizedBox(width: ChatDimensions.paddingSM),
          Flexible(
            child: Text(
              widget.message.content,
              style: ChatTextStyles.systemText.copyWith(
                color: ChatColors.accent,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      padding: ChatDimensions.messagePadding,
      decoration: BoxDecoration(
        color: ChatColors.online.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ChatDimensions.radiusMD),
        border: Border.all(
          color: ChatColors.online.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: ChatColors.online,
          ),
          const SizedBox(width: ChatDimensions.paddingSM),
          Flexible(
            child: Text(
              widget.message.content,
              style: ChatTextStyles.systemText.copyWith(
                color: ChatColors.online,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 250,
        maxHeight: 300,
      ),
      decoration: BoxDecoration(
        borderRadius: _getMessageBorderRadius(),
        boxShadow: ChatShadows.card,
      ),
      child: ClipRRect(
        borderRadius: _getMessageBorderRadius(),
        child: widget.message.imageUrl != null
          ? Image.network(
              widget.message.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildImageError();
              },
            )
          : _buildImageError(),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 120,
      color: ChatColors.otherMessage,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: ChatColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: ChatDimensions.paddingSM),
            Text(
              '이미지를 로드할 수 없습니다',
              style: ChatTextStyles.systemText,
            ),
          ],
        ),
      ),
    );
  }

  BorderRadius _getMessageBorderRadius() {
    const radius = ChatDimensions.radiusLG;
    
    if (widget.isMe) {
      return const BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(8),
      );
    } else {
      return const BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(radius),
      );
    }
  }

  Widget _buildMessageInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTimestamp(widget.message.timestamp),
          style: ChatTextStyles.timestampText,
        ),
        if (widget.isMe) ...[
          const SizedBox(width: ChatDimensions.paddingSM),
          _buildReadStatus(),
        ],
      ],
    );
  }

  Widget _buildReadStatus() {
    if (widget.message.isRead) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ChatColors.primary,
            width: 1.5,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ChatColors.primary,
          ),
        ),
      );
    } else {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ChatColors.textSecondary,
            width: 1,
          ),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
}

// 위치 공유 메시지 카드
class LocationMessageCard extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const LocationMessageCard({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: ChatColors.locationBackground,
        borderRadius: BorderRadius.circular(ChatDimensions.radiusMD),
        boxShadow: ChatShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지도 미리보기
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: ChatColors.locationBackground.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(ChatDimensions.radiusMD),
                topRight: Radius.circular(ChatDimensions.radiusMD),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: ChatDimensions.paddingSM),
                  Text(
                    '위치 공유',
                    style: ChatTextStyles.messageText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 주소 정보
          Padding(
            padding: ChatDimensions.messagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.address != null)
                  Text(
                    message.address!,
                    style: ChatTextStyles.messageText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (message.latitude != null && message.longitude != null)
                  Text(
                    '${message.latitude!.toStringAsFixed(6)}, ${message.longitude!.toStringAsFixed(6)}',
                    style: ChatTextStyles.timestampText.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                const SizedBox(height: ChatDimensions.paddingSM),
                
                // 위치 보기 버튼
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ChatDimensions.paddingMD,
                    vertical: ChatDimensions.paddingSM,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ChatDimensions.radiusSM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map,
                        size: 16,
                        color: ChatColors.locationBackground,
                      ),
                      const SizedBox(width: ChatDimensions.paddingSM),
                      Text(
                        '위치 보기',
                        style: ChatTextStyles.systemText.copyWith(
                          color: ChatColors.locationBackground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 빠른 응답 메시지 칩
class QuickReplyMessageChip extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const QuickReplyMessageChip({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ChatDimensions.paddingMD,
        vertical: ChatDimensions.paddingSM,
      ),
      decoration: BoxDecoration(
        color: _getQuickReplyColor(),
        borderRadius: BorderRadius.circular(ChatDimensions.radiusXL),
        boxShadow: ChatShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getQuickReplyIcon(),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: ChatDimensions.paddingSM),
          Text(
            message.content,
            style: ChatTextStyles.quickReplyText,
          ),
        ],
      ),
    );
  }

  Color _getQuickReplyColor() {
    if (message.quickReplyType == null) return ChatColors.quickReplyBackground;
    
    switch (message.quickReplyType!) {
      case QuickReplyType.arrived:
        return ChatColors.online;
      case QuickReplyType.late5min:
      case QuickReplyType.late10min:
      case QuickReplyType.late15min:
        return ChatColors.away;
      case QuickReplyType.cancel:
        return ChatColors.accent;
      case QuickReplyType.onWay:
        return ChatColors.primary;
    }
  }

  IconData _getQuickReplyIcon() {
    if (message.quickReplyType == null) return Icons.message;
    
    switch (message.quickReplyType!) {
      case QuickReplyType.arrived:
        return Icons.location_on;
      case QuickReplyType.late5min:
      case QuickReplyType.late10min:
      case QuickReplyType.late15min:
        return Icons.access_time;
      case QuickReplyType.cancel:
        return Icons.cancel;
      case QuickReplyType.onWay:
        return Icons.directions_run;
    }
  }
}