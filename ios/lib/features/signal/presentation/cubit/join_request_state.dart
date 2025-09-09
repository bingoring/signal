part of 'join_request_cubit.dart';

enum JoinRequestStatus {
  initial,
  loading,
  loaded,
  error,
}

enum SubmitStatus {
  initial,
  submitting,
  submitted,
  failed,
}

enum ActionStatus {
  initial,
  processing,
  success,
  failed,
}

class JoinRequestState extends Equatable {
  final JoinRequestStatus status;
  final List<SignalJoinRequest> joinRequests;
  final String? error;
  final SubmitStatus submitStatus;
  final String? submitError;
  final ActionStatus actionStatus;
  final String? actionError;

  const JoinRequestState({
    this.status = JoinRequestStatus.initial,
    this.joinRequests = const [],
    this.error,
    this.submitStatus = SubmitStatus.initial,
    this.submitError,
    this.actionStatus = ActionStatus.initial,
    this.actionError,
  });

  JoinRequestState copyWith({
    JoinRequestStatus? status,
    List<SignalJoinRequest>? joinRequests,
    String? error,
    SubmitStatus? submitStatus,
    String? submitError,
    ActionStatus? actionStatus,
    String? actionError,
  }) {
    return JoinRequestState(
      status: status ?? this.status,
      joinRequests: joinRequests ?? this.joinRequests,
      error: error ?? this.error,
      submitStatus: submitStatus ?? this.submitStatus,
      submitError: submitError ?? this.submitError,
      actionStatus: actionStatus ?? this.actionStatus,
      actionError: actionError ?? this.actionError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        joinRequests,
        error,
        submitStatus,
        submitError,
        actionStatus,
        actionError,
      ];
}