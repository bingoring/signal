part of 'signal_detail_cubit.dart';

enum SignalDetailStatus {
  initial,
  loading,
  success,
  failure,
  deleted,
}

class SignalDetailState extends Equatable {
  final SignalDetailStatus status;
  final Signal? signal;
  final List<SignalParticipant> participants;
  final bool isCreator;
  final String? userParticipationStatus;
  final bool isLoadingParticipants;
  final String errorMessage;
  final String successMessage;

  const SignalDetailState({
    required this.status,
    this.signal,
    required this.participants,
    required this.isCreator,
    this.userParticipationStatus,
    required this.isLoadingParticipants,
    required this.errorMessage,
    required this.successMessage,
  });

  factory SignalDetailState.initial() {
    return const SignalDetailState(
      status: SignalDetailStatus.initial,
      signal: null,
      participants: [],
      isCreator: false,
      userParticipationStatus: null,
      isLoadingParticipants: false,
      errorMessage: '',
      successMessage: '',
    );
  }

  SignalDetailState copyWith({
    SignalDetailStatus? status,
    Signal? signal,
    List<SignalParticipant>? participants,
    bool? isCreator,
    String? userParticipationStatus,
    bool? isLoadingParticipants,
    String? errorMessage,
    String? successMessage,
  }) {
    return SignalDetailState(
      status: status ?? this.status,
      signal: signal ?? this.signal,
      participants: participants ?? this.participants,
      isCreator: isCreator ?? this.isCreator,
      userParticipationStatus: userParticipationStatus ?? this.userParticipationStatus,
      isLoadingParticipants: isLoadingParticipants ?? this.isLoadingParticipants,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  bool get isLoading => status == SignalDetailStatus.loading;
  bool get isSuccess => status == SignalDetailStatus.success;
  bool get isFailure => status == SignalDetailStatus.failure;
  bool get isDeleted => status == SignalDetailStatus.deleted;
  bool get hasError => errorMessage.isNotEmpty;
  bool get hasSuccess => successMessage.isNotEmpty;

  bool get canJoin {
    if (signal == null) return false;
    if (isCreator) return false;
    if (userParticipationStatus != null) return false;
    if (signal!.currentParticipants >= signal!.maxParticipants) return false;
    if (signal!.status != 'active') return false;
    return true;
  }

  bool get canCancelJoinRequest {
    return userParticipationStatus == 'pending';
  }

  bool get canOpenChatRoom {
    return userParticipationStatus == 'approved' || isCreator;
  }

  bool get canManageSignal {
    return isCreator && signal != null && signal!.status != 'completed';
  }

  @override
  List<Object?> get props => [
        status,
        signal,
        participants,
        isCreator,
        userParticipationStatus,
        isLoadingParticipants,
        errorMessage,
        successMessage,
      ];
}

// Domain models for signal detail
class SignalDetail {
  final Signal signal;
  final List<SignalParticipant> participants;
  final bool isCreator;
  final String? userParticipationStatus;

  SignalDetail({
    required this.signal,
    required this.participants,
    required this.isCreator,
    this.userParticipationStatus,
  });
}