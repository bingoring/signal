import 'package:flutter/material.dart';

class ChatRoomPage extends StatelessWidget {
  final String roomId;
  
  const ChatRoomPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('채팅방')),
      body: Center(child: Text('채팅방 $roomId')),
    );
  }
}