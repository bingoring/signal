import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_theme.dart';
import 'quick_action_panel.dart';
import '../pages/chat_room_page.dart';

class EnhancedMessageInput extends StatefulWidget {
  final Function(String)? onSendMessage;
  final Function(QuickReplyType)? onQuickReply;
  final VoidCallback? onLocationShare;
  final VoidCallback? onImagePicker;

  const EnhancedMessageInput({
    Key? key,
    this.onSendMessage,
    this.onQuickReply,
    this.onLocationShare,
    this.onImagePicker,
  }) : super(key: key);

  @override
  State<EnhancedMessageInput> createState() => _EnhancedMessageInputState();
}

class _EnhancedMessageInputState extends State<EnhancedMessageInput>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _sendButtonController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _sendButtonScale;
  
  bool _isQuickActionPanelVisible = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTextController();
  }

  void _setupAnimations() {
    _scaleController = AnimationController(
      duration: ChatDimensions.animationMedium,
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: ChatDimensions.animationFast,
      vsync: this,
    );
    
    _sendButtonController = AnimationController(
      duration: ChatDimensions.animationFast,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _sendButtonScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.elasticOut,
    ));
    
    _focusNode.addListener(_handleFocusChange);
  }

  void _setupTextController() {
    _textController.addListener(() {
      final hasText = _textController.text.isNotEmpty;
      if (_hasText != hasText) {
        setState(() {
          _hasText = hasText;
        });
        
        if (hasText) {
          _sendButtonController.forward();
        } else {
          _sendButtonController.reverse();
        }
      }
    });
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _scaleController.forward();
      _fadeController.forward();
      setState(() {
        _isQuickActionPanelVisible = false;
      });
    } else {
      _scaleController.reverse();
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _sendButtonController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSendMessage() {
    final message = _textController.text.trim();
    if (message.isNotEmpty) {
      widget.onSendMessage?.call(message);
      _textController.clear();
      HapticFeedback.lightImpact();
    }
  }

  void _toggleQuickActionPanel() {
    setState(() {
      _isQuickActionPanelVisible = !_isQuickActionPanelVisible;
    });
    
    if (_isQuickActionPanelVisible) {
      _focusNode.unfocus();
    }
    
    HapticFeedback.selectionClick();
  }

  void _handleQuickReply(QuickReplyType type) {
    widget.onQuickReply?.call(type);
    setState(() {
      _isQuickActionPanelVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Action Panel
        QuickActionPanel(
          isVisible: _isQuickActionPanelVisible,
          onQuickReply: _handleQuickReply,
          onLocationShare: widget.onLocationShare,
          onImagePicker: widget.onImagePicker,
        ),
        
        // Input Container
        Container(
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
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildInputRow(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quick Action Button
        QuickActionFloatingButton(
          onPressed: _toggleQuickActionPanel,
          isExpanded: _isQuickActionPanelVisible,
        ),
        
        const SizedBox(width: ChatDimensions.paddingMD),
        
        // Text Input
        Expanded(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 44,
              maxHeight: 120,
            ),
            decoration: BoxDecoration(
              color: ChatColors.background,
              borderRadius: BorderRadius.circular(ChatDimensions.radiusLG),
              border: Border.all(
                color: _focusNode.hasFocus 
                  ? ChatColors.primary.withOpacity(0.3)
                  : ChatColors.divider,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              style: ChatTextStyles.inputText,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: ChatTextStyles.inputHint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ChatDimensions.paddingMD,
                  vertical: ChatDimensions.paddingMD,
                ),
                border: InputBorder.none,
                suffixIcon: _buildCharacterCounter(),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: ChatDimensions.paddingMD),
        
        // Send Button
        _buildSendButton(),
      ],
    );
  }

  Widget? _buildCharacterCounter() {
    final textLength = _textController.text.length;
    if (textLength < 200) return null;
    
    return Padding(
      padding: const EdgeInsets.only(right: ChatDimensions.paddingSM),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          '$textLength/1000',
          style: ChatTextStyles.timestampText.copyWith(
            color: textLength > 900 
              ? ChatColors.accent 
              : ChatColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _sendButtonScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _sendButtonScale.value,
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.selectionClick();
            },
            onTap: _hasText ? _handleSendMessage : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _hasText 
                  ? ChatColors.instagramGradient
                  : null,
                color: _hasText 
                  ? null 
                  : ChatColors.textSecondary.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: _hasText ? ChatShadows.card : null,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: ChatDimensions.animationFast,
                  child: Icon(
                    _hasText ? Icons.send : Icons.send_outlined,
                    key: ValueKey(_hasText),
                    color: _hasText ? Colors.white : ChatColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Typing Indicator Component
class TypingIndicator extends StatefulWidget {
  final List<String> typingUsers;

  const TypingIndicator({
    Key? key,
    required this.typingUsers,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _dotAnimations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _dotController,
        curve: Interval(
          index * 0.2,
          0.6 + index * 0.2,
          curve: Curves.easeInOut,
        ),
      ));
    });

    if (widget.typingUsers.isNotEmpty) {
      _dotController.repeat();
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.typingUsers.isNotEmpty && oldWidget.typingUsers.isEmpty) {
      _dotController.repeat();
    } else if (widget.typingUsers.isEmpty && oldWidget.typingUsers.isNotEmpty) {
      _dotController.stop();
      _dotController.reset();
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ChatDimensions.paddingMD,
        vertical: ChatDimensions.paddingSM,
      ),
      child: Row(
        children: [
          Container(
            width: ChatDimensions.avatarSM,
            height: ChatDimensions.avatarSM,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ChatColors.textSecondary.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                widget.typingUsers.first[0].toUpperCase(),
                style: const TextStyle(
                  color: ChatColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: ChatDimensions.paddingSM),
          
          Container(
            padding: ChatDimensions.messagePadding.copyWith(
              horizontal: ChatDimensions.paddingMD,
              vertical: ChatDimensions.paddingSM,
            ),
            decoration: BoxDecoration(
              color: ChatColors.otherMessage,
              borderRadius: BorderRadius.circular(ChatDimensions.radiusLG),
              boxShadow: ChatShadows.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _dotAnimations[index],
                    builder: (context, child) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.only(
                          right: index < 2 ? 4 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: ChatColors.textSecondary.withOpacity(
                            _dotAnimations[index].value,
                          ),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(width: ChatDimensions.paddingSM),
                Text(
                  '입력 중...',
                  style: ChatTextStyles.systemText.copyWith(
                    fontSize: 12,
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