import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'signal_model.g.dart';

@JsonSerializable()
class SignalModel extends Equatable {
  final int id;
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
  final String? placeName;
  final DateTime scheduledAt;
  final DateTime expiresAt;
  final int maxParticipants;
  final int currentParticipants;
  final int? minAge;
  final int? maxAge;
  final bool allowInstantJoin;
  final bool requireApproval;
  final String? genderPreference;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel creator;
  final double? distance; // 사용자로부터의 거리 (미터)

  const SignalModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeName,
    required this.scheduledAt,
    required this.expiresAt,
    required this.maxParticipants,
    required this.currentParticipants,
    this.minAge,
    this.maxAge,
    required this.allowInstantJoin,
    required this.requireApproval,
    this.genderPreference,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.creator,
    this.distance,
  });

  factory SignalModel.fromJson(Map<String, dynamic> json) => _$SignalModelFromJson(json);
  Map<String, dynamic> toJson() => _$SignalModelToJson(this);

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    category,
    latitude,
    longitude,
    address,
    placeName,
    scheduledAt,
    expiresAt,
    maxParticipants,
    currentParticipants,
    minAge,
    maxAge,
    allowInstantJoin,
    requireApproval,
    genderPreference,
    status,
    createdAt,
    updatedAt,
    creator,
    distance,
  ];
}

@JsonSerializable()
class UserModel extends Equatable {
  final int id;
  final String email;
  final String? username;
  final bool isActive;
  final UserProfileModel? profile;

  const UserModel({
    required this.id,
    required this.email,
    this.username,
    required this.isActive,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  @override
  List<Object?> get props => [id, email, username, isActive, profile];
}

@JsonSerializable()
class UserProfileModel extends Equatable {
  final String? displayName;
  final String? bio;
  final String? profileImageUrl;
  final int age;
  final String gender;
  final double mannerScore;
  final int totalRatings;

  const UserProfileModel({
    this.displayName,
    this.bio,
    this.profileImageUrl,
    required this.age,
    required this.gender,
    required this.mannerScore,
    required this.totalRatings,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) => _$UserProfileModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileModelToJson(this);

  @override
  List<Object?> get props => [displayName, bio, profileImageUrl, age, gender, mannerScore, totalRatings];
}

@JsonSerializable()
class SignalUpdateModel extends Equatable {
  final String type;
  final SignalModel? signal;
  final String? message;

  const SignalUpdateModel({
    required this.type,
    this.signal,
    this.message,
  });

  factory SignalUpdateModel.fromJson(Map<String, dynamic> json) => _$SignalUpdateModelFromJson(json);
  Map<String, dynamic> toJson() => _$SignalUpdateModelToJson(this);

  @override
  List<Object?> get props => [type, signal, message];
}

enum SignalUpdateType {
  signalCreated,
  signalUpdated,
  signalExpired,
  signalFull,
}