import 'package:equatable/equatable.dart';
import 'package:signal_app/features/auth/domain/entities/user.dart';

enum ParticipantStatus {
  pending,
  approved,
  rejected,
  left,
}

class SignalParticipant extends Equatable {
  final String id;
  final String signalId;
  final User user;
  final ParticipantStatus status;
  final String message;
  final DateTime createdAt;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final bool isHost;

  const SignalParticipant({
    required this.id,
    required this.signalId,
    required this.user,
    required this.status,
    required this.message,
    required this.createdAt,
    this.joinedAt,
    this.leftAt,
    required this.isHost,
  });

  SignalParticipant copyWith({
    String? id,
    String? signalId,
    User? user,
    ParticipantStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool? isHost,
  }) {
    return SignalParticipant(
      id: id ?? this.id,
      signalId: signalId ?? this.signalId,
      user: user ?? this.user,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isHost: isHost ?? this.isHost,
    );
  }

  bool get isApproved => status == ParticipantStatus.approved;
  bool get isPending => status == ParticipantStatus.pending;
  bool get isRejected => status == ParticipantStatus.rejected;
  bool get hasLeft => status == ParticipantStatus.left;

  String get statusText {
    switch (status) {
      case ParticipantStatus.pending:
        return '승인 대기';
      case ParticipantStatus.approved:
        return '참여 중';
      case ParticipantStatus.rejected:
        return '거부됨';
      case ParticipantStatus.left:
        return '나감';
    }
  }

  @override
  List<Object?> get props => [
        id,
        signalId,
        user,
        status,
        message,
        createdAt,
        joinedAt,
        leftAt,
        isHost,
      ];
}

extension ParticipantStatusExtension on ParticipantStatus {
  String get name {
    switch (this) {
      case ParticipantStatus.pending:
        return 'pending';
      case ParticipantStatus.approved:
        return 'approved';
      case ParticipantStatus.rejected:
        return 'rejected';
      case ParticipantStatus.left:
        return 'left';
    }
  }

  static ParticipantStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ParticipantStatus.pending;
      case 'approved':
        return ParticipantStatus.approved;
      case 'rejected':
        return ParticipantStatus.rejected;
      case 'left':
        return ParticipantStatus.left;
      default:
        throw ArgumentError('Unknown participant status: $status');
    }
  }
}