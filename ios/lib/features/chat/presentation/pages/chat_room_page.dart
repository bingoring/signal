import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  
  const ChatRoomPage({
    super.key, 
    required this.roomId,
    this.roomName = '채팅방',
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  WebSocketChannel? _channel;
  List<ChatMessage> _messages = [];
  bool _isConnecting = true;
  int _onlineCount = 0;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _connectToWebSocket();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  void _connectToWebSocket() {
    try {
      // TODO: Replace with your actual WebSocket URL
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8080/api/v1/chat/ws/${widget.roomId}'),
      );
      
      _channel!.stream.listen(
        _onMessageReceived,
        onError: _onWebSocketError,
        onDone: _onWebSocketClosed,
      );
      
      setState(() {
        _isConnecting = false;
      });
      
      _loadInitialMessages();
    } catch (e) {
      _handleConnectionError();
    }
  }

  void _onMessageReceived(dynamic data) {
    try {
      final Map<String, dynamic> messageData = json.decode(data);
      final message = ChatMessage.fromJson(messageData);
      
      setState(() {
        _messages.add(message);
      });
      
      _scrollToBottom();
      
      // 새 메시지 진동 피드백
      if (message.senderId != 'current_user_id') {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('메시지 파싱 오류: $e');
    }
  }

  void _onWebSocketError(error) {
    print('WebSocket 오류: $error');
    _handleConnectionError();
  }

  void _onWebSocketClosed() {
    print('WebSocket 연결 종료');
    _handleConnectionError();
  }

  void _handleConnectionError() {
    setState(() {
      _isConnecting = true;
    });
    
    // 3초 후 재연결 시도
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectToWebSocket();
    });
  }

  void _loadInitialMessages() {
    // TODO: API에서 이전 메시지들 로드
    // 임시 데이터
    setState(() {
      _messages = [
        ChatMessage(
          id: '1',
          content: '안녕하세요! 시그널에 참여해주셔서 감사합니다 😊',
          senderId: 'system',
          senderName: '시스템',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          type: MessageType.system,
        ),
        ChatMessage(
          id: '2',
          content: '모임 장소는 정확히 어디인가요?',
          senderId: 'user1',
          senderName: '김철수',
          timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
          type: MessageType.text,
        ),
        ChatMessage(
          id: '3',
          content: '스타벅스 강남점 입구에서 만나요!',
          senderId: 'current_user_id',
          senderName: '나',
          timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
          type: MessageType.text,
        ),
      ];
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || _channel == null) return;
    
    final message = {
      'type': 'text',
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _channel!.sink.add(json.encode(message));
    _messageController.clear();
    
    // 진동 피드백
    HapticFeedback.selectionClick();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildConnectionStatus(),
            Expanded(child: _buildMessageList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.roomName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_onlineCount > 0)
            Text(
              '$_onlineCount명 온라인',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showRoomInfo(),
        ),
      ],
      elevation: 1,
    );
  }

  Widget _buildConnectionStatus() {
    if (!_isConnecting) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.orange.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            '연결 중...',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '채팅을 시작해보세요!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == 'current_user_id';
        
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(message.senderName),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 12),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).primaryColor
                        : message.type == MessageType.system
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : message.type == MessageType.system
                              ? Colors.grey.shade600
                              : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTimestamp(message.timestamp),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar('나'),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showRoomInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '채팅방 정보',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('참여자'),
              subtitle: Text('$_onlineCount명'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('생성일'),
              subtitle: Text(_formatTimestamp(DateTime.now())),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.type = MessageType.text,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      senderId: json['user_id']?.toString() ?? '',
      senderName: json['username'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
    );
  }
}

enum MessageType {
  text,
  system,
  image,
}