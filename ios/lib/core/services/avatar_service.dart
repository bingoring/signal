import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:json_annotation/json_annotation.dart';

part 'avatar_service.g.dart';

@JsonSerializable()
class AvatarCategory {
  final int id;
  final String name;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String description;
  final String color;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  AvatarCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.color,
    required this.sortOrder,
  });

  factory AvatarCategory.fromJson(Map<String, dynamic> json) => _$AvatarCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$AvatarCategoryToJson(this);
}

@JsonSerializable()
class Avatar {
  final int id;
  @JsonKey(name: 'category_id')
  final int categoryId;
  final String emoji;
  final String name;
  final String description;
  final String keywords;
  @JsonKey(name: 'sort_order')
  final int sortOrder;
  @JsonKey(name: 'is_default')
  final bool isDefault;
  @JsonKey(name: 'usage_count')
  final int usageCount;
  final AvatarCategory? category;

  Avatar({
    required this.id,
    required this.categoryId,
    required this.emoji,
    required this.name,
    required this.description,
    required this.keywords,
    required this.sortOrder,
    required this.isDefault,
    required this.usageCount,
    this.category,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) => _$AvatarFromJson(json);
  Map<String, dynamic> toJson() => _$AvatarToJson(this);

  List<String> get keywordsList {
    return keywords.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
  }
}

@JsonSerializable()
class CategoryWithAvatars {
  final int id;
  final String name;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String description;
  final String color;
  final List<Avatar> avatars;

  CategoryWithAvatars({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.color,
    required this.avatars,
  });

  factory CategoryWithAvatars.fromJson(Map<String, dynamic> json) => _$CategoryWithAvatarsFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryWithAvatarsToJson(this);
}

@JsonSerializable()
class AvatarSelectionResponse {
  final List<CategoryWithAvatars> categories;
  final List<Avatar>? favorites;
  final List<Avatar>? recent;

  AvatarSelectionResponse({
    required this.categories,
    this.favorites,
    this.recent,
  });

  factory AvatarSelectionResponse.fromJson(Map<String, dynamic> json) => _$AvatarSelectionResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AvatarSelectionResponseToJson(this);
}

@JsonSerializable()
class AvatarSearchResponse {
  final String query;
  final List<Avatar> results;
  final int total;

  AvatarSearchResponse({
    required this.query,
    required this.results,
    required this.total,
  });

  factory AvatarSearchResponse.fromJson(Map<String, dynamic> json) => _$AvatarSearchResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AvatarSearchResponseToJson(this);
}

@JsonSerializable()
class SetUserAvatarRequest {
  final String emoji;

  SetUserAvatarRequest({
    required this.emoji,
  });

  factory SetUserAvatarRequest.fromJson(Map<String, dynamic> json) => _$SetUserAvatarRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SetUserAvatarRequestToJson(this);
}

@JsonSerializable()
class CategoryUsage {
  @JsonKey(name: 'category_id')
  final int categoryId;
  @JsonKey(name: 'category_name')
  final String categoryName;
  @JsonKey(name: 'usage_count')
  final int usageCount;
  final double percentage;

  CategoryUsage({
    required this.categoryId,
    required this.categoryName,
    required this.usageCount,
    required this.percentage,
  });

  factory CategoryUsage.fromJson(Map<String, dynamic> json) => _$CategoryUsageFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryUsageToJson(this);
}

@JsonSerializable()
class PersonalityTrait {
  final String name;
  final double score;
  final String description;

  PersonalityTrait({
    required this.name,
    required this.score,
    required this.description,
  });

  factory PersonalityTrait.fromJson(Map<String, dynamic> json) => _$PersonalityTraitFromJson(json);
  Map<String, dynamic> toJson() => _$PersonalityTraitToJson(this);
}

@JsonSerializable()
class AvatarPersonality {
  final String type;
  final String description;
  final List<PersonalityTrait> traits;
  final List<Avatar> suggestions;

  AvatarPersonality({
    required this.type,
    required this.description,
    required this.traits,
    required this.suggestions,
  });

  factory AvatarPersonality.fromJson(Map<String, dynamic> json) => _$AvatarPersonalityFromJson(json);
  Map<String, dynamic> toJson() => _$AvatarPersonalityToJson(this);
}

@JsonSerializable()
class UserAvatarStatsResponse {
  @JsonKey(name: 'current_avatar')
  final Avatar? currentAvatar;
  final List<Avatar> favorites;
  @JsonKey(name: 'recently_used')
  final List<Avatar> recentlyUsed;
  @JsonKey(name: 'category_stats')
  final List<CategoryUsage> categoryStats;
  @JsonKey(name: 'personality_type')
  final String personalityType;

  UserAvatarStatsResponse({
    this.currentAvatar,
    required this.favorites,
    required this.recentlyUsed,
    required this.categoryStats,
    required this.personalityType,
  });

  factory UserAvatarStatsResponse.fromJson(Map<String, dynamic> json) => _$UserAvatarStatsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UserAvatarStatsResponseToJson(this);
}

@RestApi()
abstract class AvatarService {
  factory AvatarService(Dio dio, {String baseUrl}) = _AvatarService;

  @GET('/api/avatars/categories')
  Future<HttpResponse<AvatarSelectionResponse>> getAvatarCategories();

  @GET('/api/avatars/selection')
  Future<HttpResponse<AvatarSelectionResponse>> getUserAvatarSelection();

  @GET('/api/avatars/search')
  Future<HttpResponse<AvatarSearchResponse>> searchAvatars(
    @Query('query') String query,
    @Query('category_id') int? categoryId,
    @Query('limit') int? limit,
  );

  @POST('/api/avatars/set')
  Future<HttpResponse<Map<String, dynamic>>> setUserAvatar(
    @Body() SetUserAvatarRequest request,
  );

  @POST('/api/avatars/{avatarId}/favorite')
  Future<HttpResponse<Map<String, dynamic>>> toggleAvatarFavorite(
    @Path('avatarId') int avatarId,
  );

  @GET('/api/avatars/stats')
  Future<HttpResponse<UserAvatarStatsResponse>> getUserAvatarStats();

  @GET('/api/avatars/popular')
  Future<HttpResponse<Map<String, dynamic>>> getPopularAvatars(
    @Query('limit') int? limit,
  );

  @GET('/api/avatars/default')
  Future<HttpResponse<Map<String, dynamic>>> getDefaultAvatars();

  @GET('/api/avatars/personality')
  Future<HttpResponse<AvatarPersonality>> getPersonalityAnalysis();

  @GET('/api/avatars/validate')
  Future<HttpResponse<Map<String, dynamic>>> validateAvatar(
    @Query('emoji') String emoji,
  );
}