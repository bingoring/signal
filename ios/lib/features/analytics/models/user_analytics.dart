import 'achievement.dart';

class UserAnalytics {
  final int id;
  final int userId;
  final String weekStartDate;
  final WeeklyActivityStats weeklyStats;
  final SocialImpactMetrics socialImpact;
  final TrendData trendAnalysis;
  final String createdAt;
  final String updatedAt;

  UserAnalytics({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.weeklyStats,
    required this.socialImpact,
    required this.trendAnalysis,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAnalytics.fromJson(Map<String, dynamic> json) {
    return UserAnalytics(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      weekStartDate: json['week_start_date'] as String,
      weeklyStats: WeeklyActivityStats.fromJson(json['weekly_stats'] as Map<String, dynamic>),
      socialImpact: SocialImpactMetrics.fromJson(json['social_impact'] as Map<String, dynamic>),
      trendAnalysis: TrendData.fromJson(json['trend_analysis'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'week_start_date': weekStartDate,
      'weekly_stats': weeklyStats.toJson(),
      'social_impact': socialImpact.toJson(),
      'trend_analysis': trendAnalysis.toJson(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class WeeklyActivityStats {
  final int signalsCreated;
  final int signalsJoined;
  final int totalParticipation;
  final double completionRate;
  final double averageRating;
  final int newBuddiesMade;
  final int messagesExchanged;
  final List<String> favoriteCategories;

  WeeklyActivityStats({
    required this.signalsCreated,
    required this.signalsJoined,
    required this.totalParticipation,
    required this.completionRate,
    required this.averageRating,
    required this.newBuddiesMade,
    required this.messagesExchanged,
    required this.favoriteCategories,
  });

  factory WeeklyActivityStats.fromJson(Map<String, dynamic> json) {
    return WeeklyActivityStats(
      signalsCreated: json['signals_created'] as int? ?? 0,
      signalsJoined: json['signals_joined'] as int? ?? 0,
      totalParticipation: json['total_participation'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      newBuddiesMade: json['new_buddies_made'] as int? ?? 0,
      messagesExchanged: json['messages_exchanged'] as int? ?? 0,
      favoriteCategories: (json['favorite_categories'] as List<dynamic>?)
          ?.map((e) => e.toString()).toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'signals_created': signalsCreated,
      'signals_joined': signalsJoined,
      'total_participation': totalParticipation,
      'completion_rate': completionRate,
      'average_rating': averageRating,
      'new_buddies_made': newBuddiesMade,
      'messages_exchanged': messagesExchanged,
      'favorite_categories': favoriteCategories,
    };
  }
}

class SocialImpactMetrics {
  final double communityScore;
  final double influenceRating;
  final double helpfulnessScore;
  final int leadershipEvents;
  final int positiveFeedback;
  final int mentorshipActivity;

  SocialImpactMetrics({
    required this.communityScore,
    required this.influenceRating,
    required this.helpfulnessScore,
    required this.leadershipEvents,
    required this.positiveFeedback,
    required this.mentorshipActivity,
  });

  factory SocialImpactMetrics.fromJson(Map<String, dynamic> json) {
    return SocialImpactMetrics(
      communityScore: (json['community_score'] as num?)?.toDouble() ?? 0.0,
      influenceRating: (json['influence_rating'] as num?)?.toDouble() ?? 0.0,
      helpfulnessScore: (json['helpfulness_score'] as num?)?.toDouble() ?? 0.0,
      leadershipEvents: json['leadership_events'] as int? ?? 0,
      positiveFeedback: json['positive_feedback'] as int? ?? 0,
      mentorshipActivity: json['mentorship_activity'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'community_score': communityScore,
      'influence_rating': influenceRating,
      'helpfulness_score': helpfulnessScore,
      'leadership_events': leadershipEvents,
      'positive_feedback': positiveFeedback,
      'mentorship_activity': mentorshipActivity,
    };
  }
}

class TrendData {
  final double weekOverWeekGrowth;
  final List<TimeSlot> popularTimeSlots;
  final List<LocationTrend> preferredLocations;
  final double socialNetworkGrowth;
  final String engagementTrend;

  TrendData({
    required this.weekOverWeekGrowth,
    required this.popularTimeSlots,
    required this.preferredLocations,
    required this.socialNetworkGrowth,
    required this.engagementTrend,
  });

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      weekOverWeekGrowth: (json['week_over_week_growth'] as num?)?.toDouble() ?? 0.0,
      popularTimeSlots: (json['popular_time_slots'] as List<dynamic>?)
          ?.map((json) => TimeSlot.fromJson(json as Map<String, dynamic>))
          .toList() ?? [],
      preferredLocations: (json['preferred_locations'] as List<dynamic>?)
          ?.map((json) => LocationTrend.fromJson(json as Map<String, dynamic>))
          .toList() ?? [],
      socialNetworkGrowth: (json['social_network_growth'] as num?)?.toDouble() ?? 0.0,
      engagementTrend: json['engagement_trend'] as String? ?? 'stable',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'week_over_week_growth': weekOverWeekGrowth,
      'popular_time_slots': popularTimeSlots.map((e) => e.toJson()).toList(),
      'preferred_locations': preferredLocations.map((e) => e.toJson()).toList(),
      'social_network_growth': socialNetworkGrowth,
      'engagement_trend': engagementTrend,
    };
  }
}

class TimeSlot {
  final int hour;
  final int dayOfWeek;
  final int activityCount;
  final double probability;

  TimeSlot({
    required this.hour,
    required this.dayOfWeek,
    required this.activityCount,
    required this.probability,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      hour: json['hour'] as int? ?? 0,
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      activityCount: json['activity_count'] as int? ?? 0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'day_of_week': dayOfWeek,
      'activity_count': activityCount,
      'probability': probability,
    };
  }

  String get dayName {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return days[dayOfWeek % 7];
  }

  String get timeRange {
    final startHour = hour;
    final endHour = (hour + 1) % 24;
    return '${startHour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00';
  }
}

class LocationTrend {
  final String district;
  final int visitFrequency;
  final double preferenceScore;
  final String category;

  LocationTrend({
    required this.district,
    required this.visitFrequency,
    required this.preferenceScore,
    required this.category,
  });

  factory LocationTrend.fromJson(Map<String, dynamic> json) {
    return LocationTrend(
      district: json['district'] as String? ?? '',
      visitFrequency: json['visit_frequency'] as int? ?? 0,
      preferenceScore: (json['preference_score'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'district': district,
      'visit_frequency': visitFrequency,
      'preference_score': preferenceScore,
      'category': category,
    };
  }
}

class AnalyticsSummary {
  final CurrentWeekSummary currentWeek;
  final AchievementSummary achievements;
  final SocialImpactSummary socialImpact;
  final PersonalInsightsSummary personalInsights;

  AnalyticsSummary({
    required this.currentWeek,
    required this.achievements,
    required this.socialImpact,
    required this.personalInsights,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      currentWeek: CurrentWeekSummary.fromJson(json['current_week'] as Map<String, dynamic>),
      achievements: AchievementSummary.fromJson(json['achievements'] as Map<String, dynamic>),
      socialImpact: SocialImpactSummary.fromJson(json['social_impact'] as Map<String, dynamic>),
      personalInsights: PersonalInsightsSummary.fromJson(json['personal_insights'] as Map<String, dynamic>),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'current_week': currentWeek.toJson(),
      'achievements': achievements.toJson(),
      'social_impact': socialImpact.toJson(),
      'personal_insights': personalInsights.toJson(),
    };
  }
}

class CurrentWeekSummary {
  final String weekStartDate;
  final int totalParticipation;
  final double completionRate;
  final double communityScore;
  final double weekOverWeekGrowth;
  final String engagementTrend;

  CurrentWeekSummary({
    required this.weekStartDate,
    required this.totalParticipation,
    required this.completionRate,
    required this.communityScore,
    required this.weekOverWeekGrowth,
    required this.engagementTrend,
  });

  factory CurrentWeekSummary.fromJson(Map<String, dynamic> json) {
    return CurrentWeekSummary(
      weekStartDate: json['week_start_date'] as String? ?? '',
      totalParticipation: json['total_participation'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      communityScore: (json['community_score'] as num?)?.toDouble() ?? 0.0,
      weekOverWeekGrowth: (json['week_over_week_growth'] as num?)?.toDouble() ?? 0.0,
      engagementTrend: json['engagement_trend'] as String? ?? 'stable',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'week_start_date': weekStartDate,
      'total_participation': totalParticipation,
      'completion_rate': completionRate,
      'community_score': communityScore,
      'week_over_week_growth': weekOverWeekGrowth,
      'engagement_trend': engagementTrend,
    };
  }
}

class AchievementSummary {
  final int totalUnlocked;
  final int totalAvailable;
  final double completionRate;
  final List<Achievement> recentAchievements;

  AchievementSummary({
    required this.totalUnlocked,
    required this.totalAvailable,
    required this.completionRate,
    required this.recentAchievements,
  });

  factory AchievementSummary.fromJson(Map<String, dynamic> json) {
    return AchievementSummary(
      totalUnlocked: json['total_unlocked'] as int? ?? 0,
      totalAvailable: json['total_available'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      recentAchievements: (json['recent_achievements'] as List<dynamic>?)
          ?.map((json) => Achievement.fromJson(json as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'total_unlocked': totalUnlocked,
      'total_available': totalAvailable,
      'completion_rate': completionRate,
      'recent_achievements': recentAchievements.map((e) => e.toJson()).toList(),
    };
  }
}

class SocialImpactSummary {
  final double influenceRating;
  final double helpfulnessScore;
  final int leadershipEvents;
  final int newBuddiesMade;

  SocialImpactSummary({
    required this.influenceRating,
    required this.helpfulnessScore,
    required this.leadershipEvents,
    required this.newBuddiesMade,
  });

  factory SocialImpactSummary.fromJson(Map<String, dynamic> json) {
    return SocialImpactSummary(
      influenceRating: (json['influence_rating'] as num?)?.toDouble() ?? 0.0,
      helpfulnessScore: (json['helpfulness_score'] as num?)?.toDouble() ?? 0.0,
      leadershipEvents: json['leadership_events'] as int? ?? 0,
      newBuddiesMade: json['new_buddies_made'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'influence_rating': influenceRating,
      'helpfulness_score': helpfulnessScore,
      'leadership_events': leadershipEvents,
      'new_buddies_made': newBuddiesMade,
    };
  }
}

class PersonalInsightsSummary {
  final List<String> favoriteCategories;
  final List<TimeSlot> popularTimeSlots;
  final List<LocationTrend> preferredLocations;

  PersonalInsightsSummary({
    required this.favoriteCategories,
    required this.popularTimeSlots,
    required this.preferredLocations,
  });

  factory PersonalInsightsSummary.fromJson(Map<String, dynamic> json) {
    return PersonalInsightsSummary(
      favoriteCategories: (json['favorite_categories'] as List<dynamic>?)
          ?.map((e) => e.toString()).toList() ?? [],
      popularTimeSlots: (json['popular_time_slots'] as List<dynamic>?)
          ?.map((json) => TimeSlot.fromJson(json as Map<String, dynamic>))
          .toList() ?? [],
      preferredLocations: (json['preferred_locations'] as List<dynamic>?)
          ?.map((json) => LocationTrend.fromJson(json as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'favorite_categories': favoriteCategories,
      'popular_time_slots': popularTimeSlots.map((e) => e.toJson()).toList(),
      'preferred_locations': preferredLocations.map((e) => e.toJson()).toList(),
    };
  }
}