import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:signal_app/features/signal/domain/entities/signal.dart';
import 'package:signal_app/features/signal/domain/entities/signal_participant.dart';
import 'package:signal_app/features/signal/domain/usecases/get_signal_detail_usecase.dart';
import 'package:signal_app/features/signal/domain/usecases/join_signal_usecase.dart';
import 'package:signal_app/features/signal/domain/usecases/approve_participant_usecase.dart';
import 'package:signal_app/features/signal/domain/usecases/reject_participant_usecase.dart';
import 'package:signal_app/features/signal/domain/usecases/cancel_join_request_usecase.dart';
import 'package:signal_app/features/signal/domain/usecases/delete_signal_usecase.dart';
import 'package:signal_app/features/signal/domain/usecases/complete_signal_usecase.dart';
import 'package:signal_app/core/error/failures.dart';

part 'signal_detail_state.dart';

class SignalDetailCubit extends Cubit<SignalDetailState> {
  final GetSignalDetailUseCase getSignalDetailUseCase;
  final JoinSignalUseCase joinSignalUseCase;
  final ApproveParticipantUseCase approveParticipantUseCase;
  final RejectParticipantUseCase rejectParticipantUseCase;
  final CancelJoinRequestUseCase cancelJoinRequestUseCase;
  final DeleteSignalUseCase deleteSignalUseCase;
  final CompleteSignalUseCase completeSignalUseCase;

  SignalDetailCubit({
    required this.getSignalDetailUseCase,
    required this.joinSignalUseCase,
    required this.approveParticipantUseCase,
    required this.rejectParticipantUseCase,
    required this.cancelJoinRequestUseCase,
    required this.deleteSignalUseCase,
    required this.completeSignalUseCase,
  }) : super(SignalDetailState.initial());

  void loadSignalDetail(String signalId) async {
    emit(state.copyWith(
      status: SignalDetailStatus.loading,
      isLoadingParticipants: true,
    ));

    try {
      final result = await getSignalDetailUseCase(signalId);
      
      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
            isLoadingParticipants: false,
          ));
        },
        (signalDetail) {
          emit(state.copyWith(
            status: SignalDetailStatus.success,
            signal: signalDetail.signal,
            participants: signalDetail.participants,
            isCreator: signalDetail.isCreator,
            userParticipationStatus: signalDetail.userParticipationStatus,
            isLoadingParticipants: false,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '시그널 정보를 불러오는 중 오류가 발생했습니다: ${e.toString()}',
        isLoadingParticipants: false,
      ));
    }
  }

  void joinSignal(String message) async {
    if (state.signal == null) return;

    emit(state.copyWith(status: SignalDetailStatus.loading));

    try {
      final result = await joinSignalUseCase(JoinSignalParams(
        signalId: state.signal!.id,
        message: message,
      ));

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (success) {
          // 참여 신청이 승인이 필요한 경우 pending으로, 바로 참여인 경우 approved로 설정
          final newStatus = state.signal!.requiresApproval ? 'pending' : 'approved';
          
          emit(state.copyWith(
            status: SignalDetailStatus.success,
            userParticipationStatus: newStatus,
            successMessage: state.signal!.requiresApproval 
                ? '참여 신청이 완료되었습니다. 주최자의 승인을 기다려주세요.'
                : '시그널에 성공적으로 참여했습니다!',
          ));

          // 상태 업데이트 후 최신 정보 다시 로드
          loadSignalDetail(state.signal!.id);
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '참여 신청 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void approveParticipant(String participantId) async {
    if (state.signal == null) return;

    emit(state.copyWith(status: SignalDetailStatus.loading));

    try {
      final result = await approveParticipantUseCase(ApproveParticipantParams(
        signalId: state.signal!.id,
        participantId: participantId,
      ));

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (success) {
          emit(state.copyWith(
            status: SignalDetailStatus.success,
            successMessage: '참여자를 승인했습니다.',
          ));

          // 참여자 목록 업데이트
          loadSignalDetail(state.signal!.id);
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '참여자 승인 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void rejectParticipant(String participantId) async {
    if (state.signal == null) return;

    emit(state.copyWith(status: SignalDetailStatus.loading));

    try {
      final result = await rejectParticipantUseCase(RejectParticipantParams(
        signalId: state.signal!.id,
        participantId: participantId,
      ));

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (success) {
          emit(state.copyWith(
            status: SignalDetailStatus.success,
            successMessage: '참여자를 거부했습니다.',
          ));

          // 참여자 목록 업데이트
          loadSignalDetail(state.signal!.id);
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '참여자 거부 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void cancelJoinRequest() async {
    if (state.signal == null) return;

    emit(state.copyWith(status: SignalDetailStatus.loading));

    try {
      final result = await cancelJoinRequestUseCase(state.signal!.id);

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (success) {
          emit(state.copyWith(
            status: SignalDetailStatus.success,
            userParticipationStatus: null,
            successMessage: '참여 요청을 취소했습니다.',
          ));

          // 상태 업데이트 후 최신 정보 다시 로드
          loadSignalDetail(state.signal!.id);
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '참여 요청 취소 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void deleteSignal() async {
    if (state.signal == null) return;

    emit(state.copyWith(status: SignalDetailStatus.loading));

    try {
      final result = await deleteSignalUseCase(state.signal!.id);

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (success) {
          emit(state.copyWith(
            status: SignalDetailStatus.deleted,
            successMessage: '시그널이 삭제되었습니다.',
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '시그널 삭제 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void completeSignal() async {
    if (state.signal == null) return;

    emit(state.copyWith(status: SignalDetailStatus.loading));

    try {
      final result = await completeSignalUseCase(state.signal!.id);

      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalDetailStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (success) {
          emit(state.copyWith(
            status: SignalDetailStatus.success,
            successMessage: '시그널이 완료되었습니다.',
          ));

          // 시그널 상태 업데이트
          if (state.signal != null) {
            final updatedSignal = state.signal!.copyWith(status: 'completed');
            emit(state.copyWith(signal: updatedSignal));
          }
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalDetailStatus.failure,
        errorMessage: '시그널 완료 처리 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void refreshParticipants() {
    if (state.signal != null) {
      loadSignalDetail(state.signal!.id);
    }
  }

  void clearMessages() {
    emit(state.copyWith(
      errorMessage: '',
      successMessage: '',
      status: SignalDetailStatus.success,
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      case NetworkFailure:
        return '네트워크 연결을 확인해주세요.';
      case ValidationFailure:
        return (failure as ValidationFailure).message;
      case NotFoundFailure:
        return '시그널을 찾을 수 없습니다.';
      case UnauthorizedFailure:
        return '권한이 없습니다.';
      default:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }
}

// Use case parameter classes
class JoinSignalParams {
  final String signalId;
  final String message;

  JoinSignalParams({
    required this.signalId,
    required this.message,
  });
}

class ApproveParticipantParams {
  final String signalId;
  final String participantId;

  ApproveParticipantParams({
    required this.signalId,
    required this.participantId,
  });
}

class RejectParticipantParams {
  final String signalId;
  final String participantId;

  RejectParticipantParams({
    required this.signalId,
    required this.participantId,
  });
}