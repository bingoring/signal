import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../../../../core/services/profile_service.dart';
import '../../../avatar/presentation/pages/avatar_selection_page.dart';

// Phase 1: 최소주의 프로필 시스템 UI with BLoC integration
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Load profile data on init
    context.read<ProfileBloc>().add(ProfileRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('내 프로필'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoaded) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showQuickEditDialog(context, state.profile),
                );
              }
              return Container();
            },
          ),
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is ProfileUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('프로필이 성공적으로 업데이트되었습니다'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is ProfileUpdateFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ProfileLoaded) {
            return _buildProfileContent(state.profile, state.trustStats);
          } else if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '프로필을 불러올 수 없습니다',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(state.message, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ProfileBloc>().add(ProfileRequested());
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }
          return Container();
        },
      ),
    );
  }

  Widget _buildProfileContent(ProfileData profile, TrustStats? trustStats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 매너온도 카드 (메인 정보)
          _buildMannerTemperatureCard(profile),
          const SizedBox(height: 16),
          
          // 활동 통계 카드
          _buildActivityStatsCard(profile, trustStats),
          const SizedBox(height: 16),
          
          // 프로필 정보 카드
          _buildProfileInfoCard(profile),
          const SizedBox(height: 16),
          
          // 설정 카드
          _buildSettingsCard(profile),
          const SizedBox(height: 32),
          
          // 온도 업데이트 버튼
          _buildUpdateTemperatureButton(),
        ],
      ),
    );
  }

  Widget _buildMannerTemperatureCard(ProfileData profile) {
    final temp = profile.mannerTemperature;
    final trustLevel = _getTrustLevel(temp);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _getTemperatureGradient(temp),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                profile.avatar ?? '😊',
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (profile.oneLine?.isNotEmpty == true)
                      Text(
                        profile.oneLine!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '매너온도',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '${temp.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '신뢰도 $trustLevel',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStatsCard(ProfileData profile, TrustStats? trustStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '활동 통계',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '생성한 Signal',
                  profile.signalCount.toString(),
                  Icons.add_circle_outline,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '참여한 Signal',
                  profile.joinCount.toString(),
                  Icons.group_outlined,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '완료율',
                  '${profile.completionRate.toStringAsFixed(1)}%',
                  Icons.check_circle_outline,
                  Colors.orange,
                ),
              ),
              if (trustStats != null)
                Expanded(
                  child: _buildStatItem(
                    '상위 순위',
                    '${trustStats.rankPercentage.toStringAsFixed(0)}%',
                    Icons.trending_up,
                    Colors.purple,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard(ProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '프로필 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Text(
                '닉네임: ${profile.displayName}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          if (profile.oneLine?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '한 줄 소개: ${profile.oneLine}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Text(
                '가입일: ${_formatDate(profile.createdAt)}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(ProfileData profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.notifications_outlined, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('알림 설정', style: TextStyle(fontSize: 16))),
              Switch(
                value: profile.notificationsEnabled,
                onChanged: (value) {
                  context.read<ProfileBloc>().add(
                    ProfileUpdated(
                      UpdateProfileRequest(notificationsEnabled: value),
                    ),
                  );
                },
                activeColor: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateTemperatureButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.read<ProfileBloc>().add(MannerTemperatureUpdateRequested());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('매너온도를 업데이트 중입니다...'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '매너온도 업데이트',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showQuickEditDialog(BuildContext context, ProfileData profile) {
    final displayNameController = TextEditingController(text: profile.displayName);
    final oneLineController = TextEditingController(text: profile.oneLine ?? '');
    String selectedAvatar = profile.avatar ?? '😊';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('프로필 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(
                  labelText: '닉네임 (2-30자)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 30,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: oneLineController,
                decoration: const InputDecoration(
                  labelText: '한 줄 소개 (선택사항, 50자 이하)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 50,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // 새로운 아바타 선택 버튼
              GestureDetector(
                onTap: () async {
                  Navigator.of(dialogContext).pop(); // 현재 다이얼로그 닫기
                  
                  // 아바타 선택 페이지 열기
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AvatarSelectionPage(
                        currentAvatar: selectedAvatar,
                        onAvatarSelected: (emoji) {
                          selectedAvatar = emoji;
                          // 프로필 업데이트 및 다이얼로그 다시 열기
                          _updateProfileWithNewAvatar(
                            context,
                            displayNameController.text.trim(),
                            oneLineController.text.trim(),
                            selectedAvatar,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.blue.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            selectedAvatar,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '아바타 선택',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '다양한 아바타 컬렉션에서 선택',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final displayName = displayNameController.text.trim();
              if (displayName.length < 2 || displayName.length > 30) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('닉네임은 2-30자로 입력해주세요')),
                );
                return;
              }

              final oneLine = oneLineController.text.trim().isEmpty 
                  ? null 
                  : oneLineController.text.trim();

              context.read<ProfileBloc>().add(
                ProfileUpdated(
                  UpdateProfileRequest(
                    displayName: displayName,
                    avatar: selectedAvatar,
                    oneLine: oneLine,
                  ),
                ),
              );

              Navigator.of(dialogContext).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _updateProfileWithNewAvatar(
    BuildContext context,
    String displayName,
    String oneLine,
    String avatar,
  ) {
    if (displayName.isEmpty || displayName.length < 2 || displayName.length > 30) {
      displayName = '사용자'; // 기본값
    }

    final oneLineText = oneLine.isEmpty ? null : oneLine;

    context.read<ProfileBloc>().add(
      ProfileUpdated(
        UpdateProfileRequest(
          displayName: displayName,
          avatar: avatar,
          oneLine: oneLineText,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('새로운 아바타로 프로필이 업데이트되었습니다 ✨'),
        backgroundColor: Colors.green,
      ),
    );
  }

  LinearGradient _getTemperatureGradient(double temp) {
    if (temp >= 45.0) {
      return const LinearGradient(
        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], // 매우 높음 - 초록
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (temp >= 40.0) {
      return const LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF1565C0)], // 높음 - 파랑
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (temp >= 35.0) {
      return const LinearGradient(
        colors: [Color(0xFFFF9800), Color(0xFFE65100)], // 보통 - 주황
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (temp >= 30.0) {
      return const LinearGradient(
        colors: [Color(0xFFF44336), Color(0xFFC62828)], // 낮음 - 빨강
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF9E9E9E), Color(0xFF424242)], // 매우 낮음 - 회색
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  String _getTrustLevel(double temp) {
    if (temp >= 45.0) return '매우 높음';
    if (temp >= 40.0) return '높음';
    if (temp >= 35.0) return '보통';
    if (temp >= 30.0) return '낮음';
    return '매우 낮음';
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}