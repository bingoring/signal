import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/signal.dart';
import '../../data/services/signal_api_service.dart';

part 'join_request_state.dart';

class JoinRequestCubit extends Cubit<JoinRequestState> {
  final SignalApiService _apiService;

  JoinRequestCubit({required SignalApiService apiService})
      : _apiService = apiService,
        super(const JoinRequestState());

  Future<void> loadJoinRequests(int signalId) async {
    emit(state.copyWith(status: JoinRequestStatus.loading));

    try {
      final response = await _apiService.getJoinRequests(signalId);
      
      if (response.success && response.data != null) {
        emit(state.copyWith(
          status: JoinRequestStatus.loaded,
          joinRequests: response.data!,
          error: null,
        ));
      } else {
        emit(state.copyWith(
          status: JoinRequestStatus.error,
          error: response.message.isNotEmpty ? response.message : '참가 신청서를 불러올 수 없습니다.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: JoinRequestStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> submitJoinRequest(int signalId, {String? message}) async {
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));

    try {
      final request = JoinSignalRequest(message: message);
      final response = await _apiService.joinSignal(signalId, request);
      
      if (response.success) {
        emit(state.copyWith(
          submitStatus: SubmitStatus.submitted,
          submitError: null,
        ));
        
        // 신청 후 목록 새로고침
        await loadJoinRequests(signalId);
      } else {
        emit(state.copyWith(
          submitStatus: SubmitStatus.failed,
          submitError: response.message.isNotEmpty ? response.message : '참가 신청에 실패했습니다.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        submitStatus: SubmitStatus.failed,
        submitError: e.toString(),
      ));
    }
  }

  Future<void> approveJoinRequest(int signalId, int userId, {String? message}) async {
    emit(state.copyWith(actionStatus: ActionStatus.processing));

    try {
      final request = ApproveJoinRequestRequest(userId: userId, message: message);
      final response = await _apiService.approveJoinRequest(signalId, request);
      
      if (response.success) {
        emit(state.copyWith(
          actionStatus: ActionStatus.success,
          actionError: null,
        ));
        
        // 승인 후 목록 새로고침
        await loadJoinRequests(signalId);
      } else {
        emit(state.copyWith(
          actionStatus: ActionStatus.failed,
          actionError: response.message.isNotEmpty ? response.message : '승인에 실패했습니다.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        actionStatus: ActionStatus.failed,
        actionError: e.toString(),
      ));
    }
  }

  Future<void> rejectJoinRequest(int signalId, int userId, String reason) async {
    emit(state.copyWith(actionStatus: ActionStatus.processing));

    try {
      final request = RejectJoinRequestRequest(userId: userId, reason: reason);
      final response = await _apiService.rejectJoinRequest(signalId, request);
      
      if (response.success) {
        emit(state.copyWith(
          actionStatus: ActionStatus.success,
          actionError: null,
        ));
        
        // 거절 후 목록 새로고침
        await loadJoinRequests(signalId);
      } else {
        emit(state.copyWith(
          actionStatus: ActionStatus.failed,
          actionError: response.message.isNotEmpty ? response.message : '거절에 실패했습니다.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        actionStatus: ActionStatus.failed,
        actionError: e.toString(),
      ));
    }
  }

  void clearSubmitStatus() {
    emit(state.copyWith(
      submitStatus: SubmitStatus.initial,
      submitError: null,
    ));
  }

  void clearActionStatus() {
    emit(state.copyWith(
      actionStatus: ActionStatus.initial,
      actionError: null,
    ));
  }

  void reset() {
    emit(const JoinRequestState());
  }

  // 필터링 헬퍼 메서드들
  List<SignalJoinRequest> get pendingRequests {
    return state.joinRequests
        .where((request) => request.status == JoinRequestStatus.pending)
        .toList();
  }

  List<SignalJoinRequest> get approvedRequests {
    return state.joinRequests
        .where((request) => request.status == JoinRequestStatus.approved)
        .toList();
  }

  List<SignalJoinRequest> get rejectedRequests {
    return state.joinRequests
        .where((request) => request.status == JoinRequestStatus.rejected)
        .toList();
  }

  bool hasUserRequested(int userId) {
    return state.joinRequests.any(
      (request) => request.userId == userId && 
                   request.status != JoinRequestStatus.rejected
    );
  }

  SignalJoinRequest? getUserRequest(int userId) {
    try {
      return state.joinRequests.firstWhere(
        (request) => request.userId == userId,
      );
    } catch (e) {
      return null;
    }
  }
}