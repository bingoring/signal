import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'buddy_model.g.dart';

@JsonSerializable()
class BuddyModel extends Equatable {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'buddy_id')
  final int buddyId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_interaction')
  final DateTime lastInteraction;
  @JsonKey(name: 'interaction_count')
  final int interactionCount;
  @JsonKey(name: 'total_signals')
  final int totalSignals;
  @JsonKey(name: 'compatibility_score')
  final double compatibilityScore;
  final String status;
  @JsonKey(name: 'user_name')
  final String userName;
  @JsonKey(name: 'buddy_name')
  final String buddyName;
  @JsonKey(name: 'user_display_name')
  final String? userDisplayName;
  @JsonKey(name: 'buddy_display_name')
  final String? buddyDisplayName;
  @JsonKey(name: 'user_manner_score')
  final double userMannerScore;
  @JsonKey(name: 'buddy_manner_score')
  final double buddyMannerScore;

  const BuddyModel({
    required this.id,
    required this.userId,
    required this.buddyId,
    required this.createdAt,
    required this.lastInteraction,
    required this.interactionCount,
    required this.totalSignals,
    required this.compatibilityScore,
    required this.status,
    required this.userName,
    required this.buddyName,
    this.userDisplayName,
    this.buddyDisplayName,
    required this.userMannerScore,
    required this.buddyMannerScore,
  });

  factory BuddyModel.fromJson(Map<String, dynamic> json) => _$BuddyModelFromJson(json);
  Map<String, dynamic> toJson() => _$BuddyModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        userId,
        buddyId,
        createdAt,
        lastInteraction,
        interactionCount,
        totalSignals,
        compatibilityScore,
        status,
        userName,
        buddyName,
        userDisplayName,
        buddyDisplayName,
        userMannerScore,
        buddyMannerScore,
      ];

  String get displayName => buddyDisplayName ?? buddyName;
  
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isBlocked => status == 'blocked';
  
  String get compatibilityLevel {
    if (compatibilityScore >= 8.0) return '최고';
    if (compatibilityScore >= 6.0) return '좋음';
    if (compatibilityScore >= 4.0) return '보통';
    return '낮음';
  }
  
  String get mannerLevel {
    if (buddyMannerScore >= 8.0) return '매우 좋음';
    if (buddyMannerScore >= 6.0) return '좋음';
    if (buddyMannerScore >= 4.0) return '보통';
    return '개선 필요';
  }
}

@JsonSerializable()
class PotentialBuddyModel extends Equatable {
  @JsonKey(name: 'user_id')
  final int userId;
  final String username;
  @JsonKey(name: 'display_name')
  final String? displayName;
  @JsonKey(name: 'manner_score')
  final double mannerScore;
  @JsonKey(name: 'interaction_count')
  final int interactionCount;
  @JsonKey(name: 'common_categories')
  final List<String> commonCategories;
  @JsonKey(name: 'compatibility_score')
  final double? compatibilityScore;

  const PotentialBuddyModel({
    required this.userId,
    required this.username,
    this.displayName,
    required this.mannerScore,
    required this.interactionCount,
    required this.commonCategories,
    this.compatibilityScore,
  });

  factory PotentialBuddyModel.fromJson(Map<String, dynamic> json) => _$PotentialBuddyModelFromJson(json);
  Map<String, dynamic> toJson() => _$PotentialBuddyModelToJson(this);

  @override
  List<Object?> get props => [
        userId,
        username,
        displayName,
        mannerScore,
        interactionCount,
        commonCategories,
        compatibilityScore,
      ];

  String get displayedName => displayName ?? username;
}

@JsonSerializable()
class MannerLogModel extends Equatable {
  final int id;
  @JsonKey(name: 'signal_id')
  final int? signalId;
  @JsonKey(name: 'rater_id')
  final int raterId;
  @JsonKey(name: 'ratee_id')
  final int rateeId;
  @JsonKey(name: 'score_change')
  final double scoreChange;
  final String category;
  final String? reason;
  @JsonKey(name: 'is_positive')
  final bool isPositive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const MannerLogModel({
    required this.id,
    this.signalId,
    required this.raterId,
    required this.rateeId,
    required this.scoreChange,
    required this.category,
    this.reason,
    required this.isPositive,
    required this.createdAt,
  });

  factory MannerLogModel.fromJson(Map<String, dynamic> json) => _$MannerLogModelFromJson(json);
  Map<String, dynamic> toJson() => _$MannerLogModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        signalId,
        raterId,
        rateeId,
        scoreChange,
        category,
        reason,
        isPositive,
        createdAt,
      ];

  String get categoryName {
    switch (category) {
      case 'punctuality':
        return '시간 약속';
      case 'communication':
        return '소통';
      case 'kindness':
        return '친절함';
      case 'participation':
        return '참여도';
      default:
        return category;
    }
  }
}

@JsonSerializable()
class BuddyInvitationModel extends Equatable {
  final int id;
  @JsonKey(name: 'signal_id')
  final int signalId;
  @JsonKey(name: 'inviter_id')
  final int inviterId;
  @JsonKey(name: 'invitee_id')
  final int inviteeId;
  final String status;
  final String? message;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'responded_at')
  final DateTime? respondedAt;

  const BuddyInvitationModel({
    required this.id,
    required this.signalId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    this.message,
    required this.expiresAt,
    required this.createdAt,
    this.respondedAt,
  });

  factory BuddyInvitationModel.fromJson(Map<String, dynamic> json) => _$BuddyInvitationModelFromJson(json);
  Map<String, dynamic> toJson() => _$BuddyInvitationModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        signalId,
        inviterId,
        inviteeId,
        status,
        message,
        expiresAt,
        createdAt,
        respondedAt,
      ];

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isExpired => status == 'expired' || DateTime.now().isAfter(expiresAt);
  
  String get statusText {
    switch (status) {
      case 'pending':
        return '대기 중';
      case 'accepted':
        return '수락됨';
      case 'declined':
        return '거절됨';
      case 'expired':
        return '만료됨';
      default:
        return status;
    }
  }
}

@JsonSerializable()
class BuddyStatsModel extends Equatable {
  @JsonKey(name: 'total_buddies')
  final int totalBuddies;
  @JsonKey(name: 'active_buddies')
  final int activeBuddies;
  @JsonKey(name: 'total_interactions')
  final int totalInteractions;
  @JsonKey(name: 'average_compatibility')
  final double averageCompatibility;
  @JsonKey(name: 'top_categories')
  final List<String> topCategories;
  @JsonKey(name: 'manner_score_history')
  final List<MannerScoreHistoryPoint> mannerScoreHistory;
  @JsonKey(name: 'recent_buddies')
  final List<BuddyModel> recentBuddies;
  @JsonKey(name: 'category_breakdown')
  final Map<String, double> categoryBreakdown;

  const BuddyStatsModel({
    required this.totalBuddies,
    required this.activeBuddies,
    required this.totalInteractions,
    required this.averageCompatibility,
    required this.topCategories,
    required this.mannerScoreHistory,
    required this.recentBuddies,
    required this.categoryBreakdown,
  });

  factory BuddyStatsModel.fromJson(Map<String, dynamic> json) => _$BuddyStatsModelFromJson(json);
  Map<String, dynamic> toJson() => _$BuddyStatsModelToJson(this);

  @override
  List<Object?> get props => [
        totalBuddies,
        activeBuddies,
        totalInteractions,
        averageCompatibility,
        topCategories,
        mannerScoreHistory,
        recentBuddies,
        categoryBreakdown,
      ];
}

@JsonSerializable()
class MannerScoreHistoryPoint extends Equatable {
  final DateTime date;
  final double score;

  const MannerScoreHistoryPoint({
    required this.date,
    required this.score,
  });

  factory MannerScoreHistoryPoint.fromJson(Map<String, dynamic> json) => _$MannerScoreHistoryPointFromJson(json);
  Map<String, dynamic> toJson() => _$MannerScoreHistoryPointToJson(this);

  @override
  List<Object?> get props => [date, score];
}

// Request models
@JsonSerializable()
class CreateBuddyRequest extends Equatable {
  @JsonKey(name: 'buddy_id')
  final int buddyId;
  final String? message;

  const CreateBuddyRequest({
    required this.buddyId,
    this.message,
  });

  factory CreateBuddyRequest.fromJson(Map<String, dynamic> json) => _$CreateBuddyRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateBuddyRequestToJson(this);

  @override
  List<Object?> get props => [buddyId, message];
}

@JsonSerializable()
class CreateMannerLogRequest extends Equatable {
  @JsonKey(name: 'ratee_id')
  final int rateeId;
  @JsonKey(name: 'signal_id')
  final int? signalId;
  @JsonKey(name: 'score_change')
  final double scoreChange;
  final String category;
  final String? reason;

  const CreateMannerLogRequest({
    required this.rateeId,
    this.signalId,
    required this.scoreChange,
    required this.category,
    this.reason,
  });

  factory CreateMannerLogRequest.fromJson(Map<String, dynamic> json) => _$CreateMannerLogRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateMannerLogRequestToJson(this);

  @override
  List<Object?> get props => [rateeId, signalId, scoreChange, category, reason];
}

@JsonSerializable()
class CreateBuddyInvitationRequest extends Equatable {
  @JsonKey(name: 'signal_id')
  final int signalId;
  @JsonKey(name: 'invitee_id')
  final int inviteeId;
  final String? message;

  const CreateBuddyInvitationRequest({
    required this.signalId,
    required this.inviteeId,
    this.message,
  });

  factory CreateBuddyInvitationRequest.fromJson(Map<String, dynamic> json) => _$CreateBuddyInvitationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateBuddyInvitationRequestToJson(this);

  @override
  List<Object?> get props => [signalId, inviteeId, message];
}