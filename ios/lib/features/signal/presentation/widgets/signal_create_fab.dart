import 'package:flutter/material.dart';

class SignalCreateFAB extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onPressed;

  const SignalCreateFAB({
    super.key,
    required this.animationController,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animationController.value),
          child: FloatingActionButton.extended(
            onPressed: () {
              animationController.forward().then((_) {
                animationController.reverse();
              });
              onPressed();
            },
            icon: const Icon(Icons.add_location),
            label: const Text(
              '시그널 생성',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 6,
          ),
        );
      },
    );
  }
}