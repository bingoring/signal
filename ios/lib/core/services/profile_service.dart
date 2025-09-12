import 'dart:io';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_service.g.dart';

@JsonSerializable()
class ProfileData {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'manner_temperature')
  final double mannerTemperature;
  @JsonKey(name: 'signal_count')
  final int signalCount;
  @JsonKey(name: 'join_count')
  final int joinCount;
  @JsonKey(name: 'completion_rate')
  final double completionRate;
  @JsonKey(name: 'last_activity_at')
  final String? lastActivityAt;
  @JsonKey(name: 'one_line')
  final String? oneLine;
  final String? avatar;
  @JsonKey(name: 'notifications_enabled')
  final bool notificationsEnabled;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  ProfileData({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.mannerTemperature,
    required this.signalCount,
    required this.joinCount,
    required this.completionRate,
    this.lastActivityAt,
    this.oneLine,
    this.avatar,
    required this.notificationsEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) => _$ProfileDataFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileDataToJson(this);
}

@JsonSerializable()
class MinimalProfile {
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'manner_temperature')
  final double mannerTemperature;
  @JsonKey(name: 'trust_level')
  final String trustLevel;
  @JsonKey(name: 'total_activities')
  final int totalActivities;
  @JsonKey(name: 'is_recently_active')
  final bool isRecentlyActive;
  final String? avatar;

  MinimalProfile({
    required this.displayName,
    required this.mannerTemperature,
    required this.trustLevel,
    required this.totalActivities,
    required this.isRecentlyActive,
    this.avatar,
  });

  factory MinimalProfile.fromJson(Map<String, dynamic> json) => _$MinimalProfileFromJson(json);
  Map<String, dynamic> toJson() => _$MinimalProfileToJson(this);
}

@JsonSerializable()
class TrustStats {
  @JsonKey(name: 'manner_temperature')
  final double mannerTemperature;
  @JsonKey(name: 'trust_level')
  final String trustLevel;
  @JsonKey(name: 'signal_count')
  final int signalCount;
  @JsonKey(name: 'join_count')
  final int joinCount;
  @JsonKey(name: 'completion_rate')
  final double completionRate;
  @JsonKey(name: 'total_ratings')
  final int totalRatings;
  @JsonKey(name: 'no_show_count')
  final int noShowCount;
  @JsonKey(name: 'rank_percentage')
  final double rankPercentage;

  TrustStats({
    required this.mannerTemperature,
    required this.trustLevel,
    required this.signalCount,
    required this.joinCount,
    required this.completionRate,
    required this.totalRatings,
    required this.noShowCount,
    required this.rankPercentage,
  });

  factory TrustStats.fromJson(Map<String, dynamic> json) => _$TrustStatsFromJson(json);
  Map<String, dynamic> toJson() => _$TrustStatsToJson(this);
}

@JsonSerializable()
class QuickSetupRequest {
  @JsonKey(name: 'display_name')
  final String displayName;
  final String? avatar;
  @JsonKey(name: 'one_line')
  final String? oneLine;

  QuickSetupRequest({
    required this.displayName,
    this.avatar,
    this.oneLine,
  });

  factory QuickSetupRequest.fromJson(Map<String, dynamic> json) => _$QuickSetupRequestFromJson(json);
  Map<String, dynamic> toJson() => _$QuickSetupRequestToJson(this);
}

@JsonSerializable()
class UpdateProfileRequest {
  @JsonKey(name: 'display_name')
  final String? displayName;
  final String? avatar;
  @JsonKey(name: 'one_line')
  final String? oneLine;
  @JsonKey(name: 'notifications_enabled')
  final bool? notificationsEnabled;

  UpdateProfileRequest({
    this.displayName,
    this.avatar,
    this.oneLine,
    this.notificationsEnabled,
  });

  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) => _$UpdateProfileRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateProfileRequestToJson(this);
}

@RestApi()
abstract class ProfileService {
  factory ProfileService(Dio dio, {String baseUrl}) = _ProfileService;

  @GET('/api/profile')
  Future<HttpResponse<ProfileData>> getProfile();

  @GET('/api/profile/minimal/{userId}')
  Future<HttpResponse<MinimalProfile>> getMinimalProfile(@Path('userId') int userId);

  @GET('/api/profile/trust-stats')
  Future<HttpResponse<TrustStats>> getTrustStats();

  @POST('/api/profile/quick-setup')
  Future<HttpResponse<Map<String, dynamic>>> quickSetup(@Body() QuickSetupRequest request);

  @PUT('/api/profile')
  Future<HttpResponse<ProfileData>> updateProfile(@Body() UpdateProfileRequest request);

  @POST('/api/profile/manner-temperature/update')
  Future<HttpResponse<Map<String, dynamic>>> updateMannerTemperature();
}