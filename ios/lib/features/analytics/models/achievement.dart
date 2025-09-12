class Achievement {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String description;
  final String? iconUrl;
  final String category;
  final String difficulty;
  final int progress;
  final int maxProgress;
  final bool isUnlocked;
  final String? unlockedAt;
  final String createdAt;
  final String updatedAt;

  Achievement({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.iconUrl,
    required this.category,
    required this.difficulty,
    required this.progress,
    required this.maxProgress,
    required this.isUnlocked,
    this.unlockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      progress: json['progress'] as int? ?? 0,
      maxProgress: json['max_progress'] as int? ?? 0,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'description': description,
      'icon_url': iconUrl,
      'category': category,
      'difficulty': difficulty,
      'progress': progress,
      'max_progress': maxProgress,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  double get progressPercentage {
    if (maxProgress == 0) return 0.0;
    return (progress / maxProgress * 100).clamp(0.0, 100.0);
  }

  String get difficultyEmoji {
    switch (difficulty.toLowerCase()) {
      case 'bronze':
        return '🥉';
      case 'silver':
        return '🥈';
      case 'gold':
        return '🥇';
      case 'platinum':
        return '💎';
      default:
        return '🏆';
    }
  }

  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'social':
        return '👥';
      case 'participation':
        return '🎯';
      case 'leadership':
        return '👑';
      case 'exploration':
        return '🗺️';
      case 'communication':
        return '💬';
      case 'consistency':
        return '📅';
      case 'helpfulness':
        return '🤝';
      case 'creativity':
        return '🎨';
      default:
        return '⭐';
    }
  }

  bool get isCompleted => progress >= maxProgress;
}

class AchievementData {
  final List<Achievement> achievements;
  final Map<String, List<Achievement>> byCategory;
  final int totalUnlocked;
  final int totalAvailable;

  AchievementData({
    required this.achievements,
    required this.byCategory,
    required this.totalUnlocked,
    required this.totalAvailable,
  });

  factory AchievementData.fromJson(Map<String, dynamic> json) {
    // byCategory를 Map<String, List<Achievement>>로 변환
    final byCategoryData = json['by_category'] as Map<String, dynamic>? ?? {};
    final byCategory = <String, List<Achievement>>{};
    
    for (final entry in byCategoryData.entries) {
      final categoryAchievements = (entry.value as List<dynamic>? ?? [])
          .map((achievementJson) => Achievement.fromJson(achievementJson as Map<String, dynamic>))
          .toList();
      byCategory[entry.key] = categoryAchievements;
    }

    return AchievementData(
      achievements: (json['achievements'] as List<dynamic>? ?? [])
          .map((json) => Achievement.fromJson(json as Map<String, dynamic>))
          .toList(),
      byCategory: byCategory,
      totalUnlocked: json['total_unlocked'] as int? ?? 0,
      totalAvailable: json['total_available'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievements': achievements.map((e) => e.toJson()).toList(),
      'by_category': byCategory.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      ),
      'total_unlocked': totalUnlocked,
      'total_available': totalAvailable,
    };
  }

  double get completionRate {
    if (totalAvailable == 0) return 0.0;
    return (totalUnlocked / totalAvailable * 100).clamp(0.0, 100.0);
  }

  List<Achievement> get unlockedAchievements {
    return achievements.where((achievement) => achievement.isUnlocked).toList();
  }

  List<Achievement> get inProgressAchievements {
    return achievements
        .where((achievement) => !achievement.isUnlocked && achievement.progress > 0)
        .toList();
  }

  List<Achievement> get lockedAchievements {
    return achievements
        .where((achievement) => !achievement.isUnlocked && achievement.progress == 0)
        .toList();
  }

  List<String> get availableCategories {
    return byCategory.keys.toList()..sort();
  }
}