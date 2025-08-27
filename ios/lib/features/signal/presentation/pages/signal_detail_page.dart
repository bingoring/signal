import 'package:flutter/material.dart';

class SignalDetailPage extends StatelessWidget {
  final String signalId;
  
  const SignalDetailPage({super.key, required this.signalId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시그널 상세')),
      body: Center(child: Text('시그널 $signalId 상세 페이지')),
    );
  }
}