import 'package:flutter/material.dart';

class CreateSignalPage extends StatelessWidget {
  const CreateSignalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시그널 생성')),
      body: const Center(child: Text('시그널 생성 페이지')),
    );
  }
}