part of 'signal_create_cubit.dart';

enum SignalCreateStatus {
  initial,
  loading,
  success,
  failure,
}

class SignalCreateState extends Equatable {
  final SignalCreateStatus status;
  final int currentStep;
  final String category;
  final String title;
  final String description;
  final DateTime? scheduledAt;
  final int maxParticipants;
  final double latitude;
  final double longitude;
  final String address;
  final int minAge;
  final int maxAge;
  final String genderPreference;
  final bool requiresApproval;
  final bool isPrivate;
  final String errorMessage;
  final Signal? createdSignal;

  const SignalCreateState({
    required this.status,
    required this.currentStep,
    required this.category,
    required this.title,
    required this.description,
    this.scheduledAt,
    required this.maxParticipants,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.minAge,
    required this.maxAge,
    required this.genderPreference,
    required this.requiresApproval,
    required this.isPrivate,
    required this.errorMessage,
    this.createdSignal,
  });

  factory SignalCreateState.initial() {
    return const SignalCreateState(
      status: SignalCreateStatus.initial,
      currentStep: 0,
      category: '',
      title: '',
      description: '',
      scheduledAt: null,
      maxParticipants: 4,
      latitude: 0.0,
      longitude: 0.0,
      address: '',
      minAge: 20,
      maxAge: 35,
      genderPreference: 'any',
      requiresApproval: false,
      isPrivate: false,
      errorMessage: '',
      createdSignal: null,
    );
  }

  SignalCreateState copyWith({
    SignalCreateStatus? status,
    int? currentStep,
    String? category,
    String? title,
    String? description,
    DateTime? scheduledAt,
    int? maxParticipants,
    double? latitude,
    double? longitude,
    String? address,
    int? minAge,
    int? maxAge,
    String? genderPreference,
    bool? requiresApproval,
    bool? isPrivate,
    String? errorMessage,
    Signal? createdSignal,
  }) {
    return SignalCreateState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      genderPreference: genderPreference ?? this.genderPreference,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      isPrivate: isPrivate ?? this.isPrivate,
      errorMessage: errorMessage ?? this.errorMessage,
      createdSignal: createdSignal ?? this.createdSignal,
    );
  }

  bool get isLoading => status == SignalCreateStatus.loading;
  bool get isSuccess => status == SignalCreateStatus.success;
  bool get isFailure => status == SignalCreateStatus.failure;
  bool get hasError => errorMessage.isNotEmpty;

  double get progressValue => (currentStep + 1) / 4;

  String get stepTitle {
    switch (currentStep) {
      case 0:
        return '카테고리 선택';
      case 1:
        return '시그널 정보';
      case 2:
        return '장소 선택';
      case 3:
        return '상세 설정';
      default:
        return '';
    }
  }

  String get stepDescription {
    switch (currentStep) {
      case 0:
        return '어떤 활동을 함께 할지 선택해주세요';
      case 1:
        return '시그널의 제목과 상세 정보를 입력해주세요';
      case 2:
        return '만날 장소를 선택해주세요';
      case 3:
        return '참여자 조건과 시그널 설정을 선택해주세요';
      default:
        return '';
    }
  }

  bool get canProceed {
    switch (currentStep) {
      case 0:
        return category.isNotEmpty;
      case 1:
        return title.isNotEmpty &&
               description.isNotEmpty &&
               scheduledAt != null &&
               maxParticipants > 0 &&
               (scheduledAt == null || scheduledAt!.isAfter(DateTime.now()));
      case 2:
        return latitude != 0.0 && longitude != 0.0 && address.isNotEmpty;
      case 3:
        return minAge < maxAge && minAge >= 18 && maxAge <= 65;
      default:
        return false;
    }
  }

  @override
  List<Object?> get props => [
        status,
        currentStep,
        category,
        title,
        description,
        scheduledAt,
        maxParticipants,
        latitude,
        longitude,
        address,
        minAge,
        maxAge,
        genderPreference,
        requiresApproval,
        isPrivate,
        errorMessage,
        createdSignal,
      ];
}

class CreateSignalParams {
  final String title;
  final String description;
  final String category;
  final DateTime scheduledAt;
  final double latitude;
  final double longitude;
  final String address;
  final int maxParticipants;
  final int minAge;
  final int maxAge;
  final String genderPreference;
  final bool requiresApproval;
  final bool isPrivate;

  CreateSignalParams({
    required this.title,
    required this.description,
    required this.category,
    required this.scheduledAt,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.maxParticipants,
    required this.minAge,
    required this.maxAge,
    required this.genderPreference,
    required this.requiresApproval,
    required this.isPrivate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'scheduled_at': scheduledAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'max_participants': maxParticipants,
      'min_age': minAge,
      'max_age': maxAge,
      'gender_preference': genderPreference,
      'requires_approval': requiresApproval,
      'is_private': isPrivate,
    };
  }
}