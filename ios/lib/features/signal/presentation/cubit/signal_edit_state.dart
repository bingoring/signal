part of 'signal_edit_cubit.dart';

enum SignalEditStatus {
  initial,
  editing,
  loading,
  success,
  failure,
}

class SignalEditState extends Equatable {
  final SignalEditStatus status;
  final Signal? originalSignal;
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
  final String successMessage;

  const SignalEditState({
    required this.status,
    this.originalSignal,
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
    required this.successMessage,
  });

  factory SignalEditState.initial() {
    return const SignalEditState(
      status: SignalEditStatus.initial,
      originalSignal: null,
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
      successMessage: '',
    );
  }

  factory SignalEditState.fromSignal(Signal signal) {
    return SignalEditState(
      status: SignalEditStatus.editing,
      originalSignal: signal,
      category: signal.category,
      title: signal.title,
      description: signal.description,
      scheduledAt: signal.scheduledAt,
      maxParticipants: signal.maxParticipants,
      latitude: signal.latitude,
      longitude: signal.longitude,
      address: signal.address,
      minAge: signal.minAge,
      maxAge: signal.maxAge,
      genderPreference: signal.genderPreference,
      requiresApproval: signal.requiresApproval,
      isPrivate: signal.isPrivate,
      errorMessage: '',
      successMessage: '',
    );
  }

  SignalEditState copyWith({
    SignalEditStatus? status,
    Signal? originalSignal,
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
    String? successMessage,
  }) {
    return SignalEditState(
      status: status ?? this.status,
      originalSignal: originalSignal ?? this.originalSignal,
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
      successMessage: successMessage ?? this.successMessage,
    );
  }

  bool get isLoading => status == SignalEditStatus.loading;
  bool get isSuccess => status == SignalEditStatus.success;
  bool get isFailure => status == SignalEditStatus.failure;
  bool get hasError => errorMessage.isNotEmpty;
  bool get hasSuccess => successMessage.isNotEmpty;

  bool get canSave {
    return category.isNotEmpty &&
           title.trim().length >= 5 &&
           description.trim().length >= 10 &&
           scheduledAt != null &&
           scheduledAt!.isAfter(DateTime.now()) &&
           maxParticipants >= 2 &&
           latitude != 0.0 &&
           longitude != 0.0 &&
           address.isNotEmpty &&
           minAge < maxAge &&
           minAge >= 18 &&
           maxAge <= 65;
  }

  bool get hasChanges {
    if (originalSignal == null) return false;

    return category != originalSignal!.category ||
           title != originalSignal!.title ||
           description != originalSignal!.description ||
           scheduledAt != originalSignal!.scheduledAt ||
           maxParticipants != originalSignal!.maxParticipants ||
           latitude != originalSignal!.latitude ||
           longitude != originalSignal!.longitude ||
           address != originalSignal!.address ||
           minAge != originalSignal!.minAge ||
           maxAge != originalSignal!.maxAge ||
           genderPreference != originalSignal!.genderPreference ||
           requiresApproval != originalSignal!.requiresApproval ||
           isPrivate != originalSignal!.isPrivate;
  }

  @override
  List<Object?> get props => [
        status,
        originalSignal,
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
        successMessage,
      ];
}