import 'package:flutter/material.dart';
import '../../../../core/services/avatar_service.dart';
import 'avatar_grid_item.dart';

class FavoritesSection extends StatelessWidget {
  final List<Avatar> favorites;
  final String? selectedAvatar;
  final Function(String) onAvatarSelected;

  const FavoritesSection({
    super.key,
    required this.favorites,
    this.selectedAvatar,
    required this.onAvatarSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '즐겨찾는 아바타가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아바타를 길게 눌러 즐겨찾기에 추가해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.favorite,
                color: Colors.red[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '즐겨찾기 아바타',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${favorites.length}개',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          Text(
            '자주 사용하는 아바타들을 모아보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 즐겨찾기 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final avatar = favorites[index];
              return AvatarGridItem(
                avatar: avatar,
                isSelected: selectedAvatar == avatar.emoji,
                onTap: () => onAvatarSelected(avatar.emoji),
                showPopularity: false,
                showFavoriteButton: true,
                isFavorite: true,
                onFavoriteToggle: () => _toggleFavorite(context, avatar),
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(BuildContext context, Avatar avatar) {
    // TODO: 즐겨찾기 토글 API 호출
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${avatar.name}을(를) 즐겨찾기에서 제거했습니다'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () {
            // TODO: 되돌리기 기능
          },
        ),
      ),
    );
  }
}

class RecentSection extends StatelessWidget {
  final List<Avatar> recent;
  final String? selectedAvatar;
  final Function(String) onAvatarSelected;

  const RecentSection({
    super.key,
    required this.recent,
    this.selectedAvatar,
    required this.onAvatarSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '최근 사용한 아바타가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아바타를 선택하면 여기에 기록됩니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.blue[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '최근 사용 아바타',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${recent.length}개',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          Text(
            '최근에 사용했던 아바타들을 빠르게 다시 선택하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 최근 사용 그리드
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: recent.length,
            itemBuilder: (context, index) {
              final avatar = recent[index];
              return Stack(
                children: [
                  AvatarGridItem(
                    avatar: avatar,
                    isSelected: selectedAvatar == avatar.emoji,
                    onTap: () => onAvatarSelected(avatar.emoji),
                    showPopularity: false,
                  ),
                  
                  // 최근 사용 순서 표시
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}