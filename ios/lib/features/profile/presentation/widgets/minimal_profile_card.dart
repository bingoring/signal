import 'package:flutter/material.dart';
import '../../../../core/services/profile_service.dart';

/// 다른 사용자의 최소 프로필 정보를 보여주는 카드
/// Signal 생성/참여 시 간단한 신뢰도 정보 제공
class MinimalProfileCard extends StatelessWidget {
  final MinimalProfile profile;
  final VoidCallback? onTap;
  final bool showTrustLevel;
  final bool compact;

  const MinimalProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.showTrustLevel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTemperatureColor(profile.mannerTemperature).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  profile.avatar ?? '😊',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Name and temperature
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.thermostat,
                        size: 14,
                        color: _getTemperatureColor(profile.mannerTemperature),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.mannerTemperature.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getTemperatureColor(profile.mannerTemperature),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (showTrustLevel) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getTemperatureColor(profile.mannerTemperature).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile.trustLevel,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTemperatureColor(profile.mannerTemperature),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Activity indicator
            if (profile.isRecentlyActive)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getTemperatureColor(profile.mannerTemperature).withOpacity(0.1),
              _getTemperatureColor(profile.mannerTemperature).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getTemperatureColor(profile.mannerTemperature).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getTemperatureColor(profile.mannerTemperature).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      profile.avatar ?? '😊',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: profile.isRecentlyActive ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile.isRecentlyActive ? '최근 활동' : '비활성',
                            style: TextStyle(
                              fontSize: 12,
                              color: profile.isRecentlyActive ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Trust level badge
                if (showTrustLevel)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTemperatureColor(profile.mannerTemperature),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profile.trustLevel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Temperature and activities
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '매너온도',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.mannerTemperature.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getTemperatureColor(profile.mannerTemperature),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '총 활동',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.totalActivities}회',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return Colors.green;
    if (temp >= 40.0) return Colors.blue;
    if (temp >= 35.0) return Colors.orange;
    if (temp >= 30.0) return Colors.red;
    return Colors.grey;
  }
}

/// Signal 생성자의 프로필을 보여주는 위젯
class SignalCreatorProfile extends StatelessWidget {
  final MinimalProfile profile;
  final bool showFullInfo;

  const SignalCreatorProfile({
    super.key,
    required this.profile,
    this.showFullInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Avatar with temperature color
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getTemperatureColor(profile.mannerTemperature),
                  _getTemperatureColor(profile.mannerTemperature).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                profile.avatar ?? '😊',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTemperatureColor(profile.mannerTemperature).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '호스트',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getTemperatureColor(profile.mannerTemperature),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.thermostat,
                      size: 14,
                      color: _getTemperatureColor(profile.mannerTemperature),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.mannerTemperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTemperatureColor(profile.mannerTemperature),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${profile.trustLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (showFullInfo) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• 활동 ${profile.totalActivities}회',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Activity status
          if (profile.isRecentlyActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '활성',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return Colors.green;
    if (temp >= 40.0) return Colors.blue;
    if (temp >= 35.0) return Colors.orange;
    if (temp >= 30.0) return Colors.red;
    return Colors.grey;
  }
}

/// Signal 참여자 목록에서 사용되는 프로필 리스트 아이템
class ProfileListItem extends StatelessWidget {
  final MinimalProfile profile;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ProfileListItem({
    super.key,
    required this.profile,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getTemperatureColor(profile.mannerTemperature).withOpacity(0.2),
              _getTemperatureColor(profile.mannerTemperature).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _getTemperatureColor(profile.mannerTemperature).withOpacity(0.3),
          ),
        ),
        child: Center(
          child: Text(
            profile.avatar ?? '😊',
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            profile.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          if (profile.isRecentlyActive)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            Icons.thermostat,
            size: 14,
            color: _getTemperatureColor(profile.mannerTemperature),
          ),
          const SizedBox(width: 4),
          Text(
            '${profile.mannerTemperature.toStringAsFixed(1)}°C',
            style: TextStyle(
              color: _getTemperatureColor(profile.mannerTemperature),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text('• ${profile.trustLevel}'),
          const SizedBox(width: 8),
          Text('• 활동 ${profile.totalActivities}회'),
        ],
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return Colors.green;
    if (temp >= 40.0) return Colors.blue;
    if (temp >= 35.0) return Colors.orange;
    if (temp >= 30.0) return Colors.red;
    return Colors.grey;
  }
}