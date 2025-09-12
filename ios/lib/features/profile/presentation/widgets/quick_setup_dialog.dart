import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../../../../core/services/profile_service.dart';

/// 신규 사용자를 위한 30초 빠른 설정 다이얼로그
class QuickSetupDialog extends StatefulWidget {
  final VoidCallback? onSetupComplete;

  const QuickSetupDialog({
    super.key,
    this.onSetupComplete,
  });

  @override
  State<QuickSetupDialog> createState() => _QuickSetupDialogState();

  static Future<void> show(BuildContext context, {VoidCallback? onSetupComplete}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => QuickSetupDialog(onSetupComplete: onSetupComplete),
    );
  }
}

class _QuickSetupDialogState extends State<QuickSetupDialog> {
  final _displayNameController = TextEditingController();
  final _oneLineController = TextEditingController();
  String _selectedAvatar = '😊';
  bool _isLoading = false;

  final List<String> _availableAvatars = [
    '😊', '🚀', '🎯', '🌟', '🎨', '🏃', '📚', '🎵', 
    '🍕', '⚡', '🌈', '🔥', '🌍', '📷', '🎭', '🏔️'
  ];

  @override
  void dispose() {
    _displayNameController.dispose();
    _oneLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoaded) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pop();
          widget.onSetupComplete?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필 설정이 완료되었습니다! Signal을 시작해보세요 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (state is ProfileError) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('설정 중 오류가 발생했습니다: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.rocket_launch,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '30초 빠른 설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2196F3).withOpacity(0.1),
                      const Color(0xFF1565C0).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Signal에 오신 것을 환영합니다!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '간단한 정보만으로 바로 Signal을 시작할 수 있어요.\n복잡한 프로필은 필요 없습니다!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Display name input
              const Text(
                '닉네임 *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  hintText: '예: 카페러버, 등산왕, 요리초보',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                maxLength: 30,
              ),
              const SizedBox(height: 16),
              
              // Avatar selection
              const Text(
                '아바타 선택 *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableAvatars.map((avatar) {
                    final isSelected = _selectedAvatar == avatar;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatar = avatar;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF2196F3).withOpacity(0.1)
                              : Colors.grey[50],
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF2196F3)
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            avatar,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              
              // One line intro (optional)
              const Text(
                '한 줄 소개 (선택사항)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _oneLineController,
                decoration: InputDecoration(
                  hintText: '예: 맛집 탐방을 좋아해요!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                ),
                maxLength: 50,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Info box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '매너온도는 36.5°C부터 시작하여 활동에 따라 자동으로 계산됩니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _onSetupComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '시작하기',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  void _onSetupComplete() {
    final displayName = _displayNameController.text.trim();
    
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요')),
      );
      return;
    }
    
    if (displayName.length < 2 || displayName.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임은 2-30자로 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final oneLine = _oneLineController.text.trim().isEmpty 
        ? null 
        : _oneLineController.text.trim();

    context.read<ProfileBloc>().add(
      ProfileQuickSetupRequested(
        QuickSetupRequest(
          displayName: displayName,
          avatar: _selectedAvatar,
          oneLine: oneLine,
        ),
      ),
    );
  }
}

/// 프로필 설정 완료를 안내하는 스낵바를 보여주는 헬퍼 함수
class QuickSetupHelper {
  static void showWelcomeMessage(BuildContext context, String displayName, double mannerTemperature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '환영합니다, $displayName님! 🎉',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '매너온도 ${mannerTemperature.toStringAsFixed(1)}°C로 시작합니다',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                '이제 Signal을 생성하거나 참여해보세요!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}