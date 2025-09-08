import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class AuthRequest {
  final String email;

  AuthRequest({required this.email});

  factory AuthRequest.fromJson(Map<String, dynamic> json) =>
      _$AuthRequestFromJson(json);
  
  Map<String, dynamic> toJson() => _$AuthRequestToJson(this);
}

@JsonSerializable()
class AuthResponse {
  final String message;
  final bool success;

  AuthResponse({
    required this.message,
    required this.success,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

@JsonSerializable()
class TokenVerifyResponse {
  final String token;
  @JsonKey(name: 'is_new_user')
  final bool isNewUser;
  final UserProfile user;

  TokenVerifyResponse({
    required this.token,
    required this.isNewUser,
    required this.user,
  });

  factory TokenVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$TokenVerifyResponseFromJson(json);
  
  Map<String, dynamic> toJson() => _$TokenVerifyResponseToJson(this);
}

@JsonSerializable()
class UserProfile {
  final int id;
  final String email;
  final String username;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
  
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}