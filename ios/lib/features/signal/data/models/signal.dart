import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'signal.g.dart';

@JsonSerializable()
class Signal extends Equatable {
  final int id;
  @JsonKey(name: 'creator_id')
  final int creatorId;
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
  @JsonKey(name: 'place_name')
  final String? placeName;
  @JsonKey(name: 'scheduled_at')
  final DateTime scheduledAt;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'max_participants')
  final int maxParticipants;
  @JsonKey(name: 'current_participants')
  final int currentParticipants;
  @JsonKey(name: 'min_age')
  final int? minAge;
  @JsonKey(name: 'max_age')
  final int? maxAge;
  @JsonKey(name: 'allow_instant_join')
  final bool allowInstantJoin;
  @JsonKey(name: 'require_approval')
  final bool requireApproval;
  @JsonKey(name: 'gender_preference')
  final String? genderPreference;
  final String status;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  final User? creator;
  final List<SignalParticipant>? participants;
  @JsonKey(name: 'chat_room')
  final ChatRoom? chatRoom;

  const Signal({
    required this.id,
    required this.creatorId,
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
    this.creator,
    this.participants,
    this.chatRoom,
  });

  factory Signal.fromJson(Map<String, dynamic> json) => _$SignalFromJson(json);
  Map<String, dynamic> toJson() => _$SignalToJson(this);

  Signal copyWith({
    int? id,
    int? creatorId,
    String? title,
    String? description,
    String? category,
    double? latitude,
    double? longitude,
    String? address,
    String? placeName,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? maxParticipants,
    int? currentParticipants,
    int? minAge,
    int? maxAge,
    bool? allowInstantJoin,
    bool? requireApproval,
    String? genderPreference,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? creator,
    List<SignalParticipant>? participants,
    ChatRoom? chatRoom,
  }) {
    return Signal(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      placeName: placeName ?? this.placeName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      allowInstantJoin: allowInstantJoin ?? this.allowInstantJoin,
      requireApproval: requireApproval ?? this.requireApproval,
      genderPreference: genderPreference ?? this.genderPreference,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creator: creator ?? this.creator,
      participants: participants ?? this.participants,
      chatRoom: chatRoom ?? this.chatRoom,
    );
  }

  @override
  List<Object?> get props => [
    id,
    creatorId,
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
    participants,
    chatRoom,
  ];
}

@JsonSerializable()
class SignalWithDistance extends Equatable {
  final Signal signal;
  final double? distance;

  const SignalWithDistance({
    required this.signal,
    this.distance,
  });

  factory SignalWithDistance.fromJson(Map<String, dynamic> json) => _$SignalWithDistanceFromJson(json);
  Map<String, dynamic> toJson() => _$SignalWithDistanceToJson(this);

  @override
  List<Object?> get props => [signal, distance];
}

@JsonSerializable()
class User extends Equatable {
  final int id;
  final String email;
  final String? username;
  @JsonKey(name: 'is_active')
  final bool isActive;
  final UserProfile? profile;

  const User({
    required this.id,
    required this.email,
    this.username,
    required this.isActive,
    this.profile,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [id, email, username, isActive, profile];
}

@JsonSerializable()
class UserProfile extends Equatable {
  @JsonKey(name: 'display_name')
  final String? displayName;
  final String? bio;
  @JsonKey(name: 'profile_image_url')
  final String? profileImageUrl;
  final int age;
  final String gender;
  @JsonKey(name: 'manner_score')
  final double mannerScore;
  @JsonKey(name: 'total_ratings')
  final int totalRatings;

  const UserProfile({
    this.displayName,
    this.bio,
    this.profileImageUrl,
    required this.age,
    required this.gender,
    required this.mannerScore,
    required this.totalRatings,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  @override
  List<Object?> get props => [displayName, bio, profileImageUrl, age, gender, mannerScore, totalRatings];
}

@JsonSerializable()
class SignalParticipant extends Equatable {
  final int id;
  @JsonKey(name: 'signal_id')
  final int signalId;
  @JsonKey(name: 'user_id')
  final int userId;
  final String status;
  final String? message;
  @JsonKey(name: 'joined_at')
  final DateTime? joinedAt;
  @JsonKey(name: 'left_at')
  final DateTime? leftAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  final User? user;

  const SignalParticipant({
    required this.id,
    required this.signalId,
    required this.userId,
    required this.status,
    this.message,
    this.joinedAt,
    this.leftAt,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  factory SignalParticipant.fromJson(Map<String, dynamic> json) => _$SignalParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$SignalParticipantToJson(this);

  @override
  List<Object?> get props => [id, signalId, userId, status, message, joinedAt, leftAt, createdAt, updatedAt, user];
}

@JsonSerializable()
class ChatRoom extends Equatable {
  final int id;
  @JsonKey(name: 'signal_id')
  final int signalId;
  final String name;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const ChatRoom({
    required this.id,
    required this.signalId,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => _$ChatRoomFromJson(json);
  Map<String, dynamic> toJson() => _$ChatRoomToJson(this);

  @override
  List<Object?> get props => [id, signalId, name, isActive, createdAt, updatedAt];
}

// 요청 모델들
@JsonSerializable()
class CreateSignalRequest extends Equatable {
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
  @JsonKey(name: 'place_name')
  final String? placeName;
  @JsonKey(name: 'scheduled_at')
  final DateTime scheduledAt;
  @JsonKey(name: 'max_participants')
  final int maxParticipants;
  @JsonKey(name: 'min_age')
  final int? minAge;
  @JsonKey(name: 'max_age')
  final int? maxAge;
  @JsonKey(name: 'allow_instant_join')
  final bool allowInstantJoin;
  @JsonKey(name: 'require_approval')
  final bool requireApproval;
  @JsonKey(name: 'gender_preference')
  final String? genderPreference;

  const CreateSignalRequest({
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeName,
    required this.scheduledAt,
    required this.maxParticipants,
    this.minAge,
    this.maxAge,
    required this.allowInstantJoin,
    required this.requireApproval,
    this.genderPreference,
  });

  factory CreateSignalRequest.fromJson(Map<String, dynamic> json) => _$CreateSignalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateSignalRequestToJson(this);

  @override
  List<Object?> get props => [
    title,
    description,
    category,
    latitude,
    longitude,
    address,
    placeName,
    scheduledAt,
    maxParticipants,
    minAge,
    maxAge,
    allowInstantJoin,
    requireApproval,
    genderPreference,
  ];
}

@JsonSerializable()
class SearchSignalRequest extends Equatable {
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String? category;
  @JsonKey(name: 'start_time')
  final DateTime? startTime;
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  final int page;
  final int limit;

  const SearchSignalRequest({
    this.latitude,
    this.longitude,
    this.radius,
    this.category,
    this.startTime,
    this.endTime,
    this.page = 1,
    this.limit = 20,
  });

  factory SearchSignalRequest.fromJson(Map<String, dynamic> json) => _$SearchSignalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SearchSignalRequestToJson(this);

  @override
  List<Object?> get props => [latitude, longitude, radius, category, startTime, endTime, page, limit];
}

@JsonSerializable()
class JoinSignalRequest extends Equatable {
  final String? message;

  const JoinSignalRequest({this.message});

  factory JoinSignalRequest.fromJson(Map<String, dynamic> json) => _$JoinSignalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$JoinSignalRequestToJson(this);

  @override
  List<Object?> get props => [message];
}

// 상수 정의
class SignalStatus {
  static const String active = 'active';
  static const String full = 'full';
  static const String closed = 'closed';
  static const String cancelled = 'cancelled';
  static const String completed = 'completed';
}

class ParticipantStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String left = 'left';
  static const String noShow = 'no_show';
}

class InterestCategory {
  static const String sports = 'sports';
  static const String food = 'food';
  static const String culture = 'culture';
  static const String study = 'study';
  static const String hobby = 'hobby';
  static const String travel = 'travel';
  static const String shopping = 'shopping';
  static const String entertainment = 'entertainment';
}