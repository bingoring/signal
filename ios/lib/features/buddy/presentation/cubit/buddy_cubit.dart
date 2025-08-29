import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/models/buddy_model.dart';
import '../../data/services/buddy_api_service.dart';
import 'buddy_state.dart';

@injectable
class BuddyCubit extends Cubit<BuddyState> {
  final BuddyApiService _apiService;

  BuddyCubit(this._apiService) : super(const BuddyState());

  static const int _pageSize = 20;

  // 단골 목록 로드
  Future<void> loadBuddies({bool refresh = false}) async {
    if (refresh || state.buddies.isEmpty) {
      emit(state.copyWith(
        isLoading: true,
        clearError: true,
        currentPage: 1,
      ));
    }

    try {
      final buddies = await _apiService.getBuddies(
        page: refresh ? 1 : state.currentPage,
        limit: _pageSize,
        status: state.currentFilters?['status'],
        sortBy: state.currentFilters?['sortBy'] ?? 'last_interaction',
        sortOrder: state.currentFilters?['sortOrder'] ?? 'desc',
        minCompatibility: state.currentFilters?['minCompatibility'],
        minInteractions: state.currentFilters?['minInteractions'],
      );

      final newBuddies = refresh ? buddies : [...state.buddies, ...buddies];

      emit(state.copyWith(
        isLoading: false,
        buddies: newBuddies,
        hasMoreBuddies: buddies.length >= _pageSize,
        currentPage: refresh ? 2 : state.currentPage + 1,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  // 더 많은 단골 로드
  Future<void> loadMoreBuddies() async {
    if (state.hasMoreBuddies && !state.isLoading) {
      await loadBuddies();
    }
  }

  // 단골 목록 새로고침
  Future<void> refreshBuddies() async {
    await loadBuddies(refresh: true);
  }

  // 단골 필터링
  Future<void> filterBuddies(Map<String, dynamic> filters) async {
    emit(state.copyWith(
      currentFilters: filters,
      buddies: [],
      currentPage: 1,
      hasMoreBuddies: true,
    ));
    await loadBuddies(refresh: true);
  }

  // 단골 통계 로드
  Future<void> loadBuddyStats() async {
    emit(state.copyWith(isLoadingStats: true, clearStatsError: true));

    try {
      final stats = await _apiService.getBuddyStats();
      emit(state.copyWith(
        isLoadingStats: false,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingStats: false,
        statsError: e.toString(),
      ));
    }
  }

  // 단골 후보자 로드
  Future<void> loadPotentialBuddies({
    int minInteractions = 2,
    double minMannerScore = 4.0,
  }) async {
    emit(state.copyWith(clearPotentialError: true));

    try {
      final potentialBuddies = await _apiService.getPotentialBuddies(
        minInteractions: minInteractions,
        minMannerScore: minMannerScore,
      );
      
      emit(state.copyWith(potentialBuddies: potentialBuddies));
    } catch (e) {
      emit(state.copyWith(potentialError: e.toString()));
    }
  }

  // 단골 관계 생성
  Future<bool> createBuddy(int buddyId, {String? message}) async {
    try {
      final request = CreateBuddyRequest(
        buddyId: buddyId,
        message: message,
      );
      
      await _apiService.createBuddy(request);
      
      // 목록 새로고침
      await refreshBuddies();
      await loadBuddyStats();
      
      return true;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return false;
    }
  }

  // 단골 관계 수정
  Future<bool> updateBuddy(
    int buddyId, {
    String? status,
    double? compatibilityScore,
    String? notes,
  }) async {
    try {
      await _apiService.updateBuddy(
        buddyId,
        status: status,
        compatibilityScore: compatibilityScore,
        notes: notes,
      );

      // 목록 새로고침
      await refreshBuddies();
      return true;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return false;
    }
  }

  // 단골 관계 삭제
  Future<bool> deleteBuddy(int buddyId) async {
    try {
      await _apiService.deleteBuddy(buddyId);
      
      // 목록에서 제거
      final updatedBuddies = state.buddies
          .where((buddy) => buddy.buddyId != buddyId)
          .toList();
      
      emit(state.copyWith(buddies: updatedBuddies));
      await loadBuddyStats();
      
      return true;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return false;
    }
  }

  // 매너 점수 평가
  Future<bool> createMannerLog({
    required int rateeId,
    int? signalId,
    required double scoreChange,
    required String category,
    String? reason,
  }) async {
    try {
      final request = CreateMannerLogRequest(
        rateeId: rateeId,
        signalId: signalId,
        scoreChange: scoreChange,
        category: category,
        reason: reason,
      );

      await _apiService.createMannerLog(request);
      
      // 통계 새로고침
      await loadBuddyStats();
      return true;
    } catch (e) {
      emit(state.copyWith(mannerError: e.toString()));
      return false;
    }
  }

  // 매너 점수 이력 로드
  Future<void> loadMannerLogs({bool refresh = false}) async {
    if (refresh || state.mannerLogs.isEmpty) {
      emit(state.copyWith(clearMannerError: true, logsPage: 1));
    }

    try {
      final logs = await _apiService.getMannerLogs(
        page: refresh ? 1 : state.logsPage,
        limit: _pageSize,
      );

      final newLogs = refresh ? logs : [...state.mannerLogs, ...logs];

      emit(state.copyWith(
        mannerLogs: newLogs,
        hasMoreLogs: logs.length >= _pageSize,
        logsPage: refresh ? 2 : state.logsPage + 1,
      ));
    } catch (e) {
      emit(state.copyWith(mannerError: e.toString()));
    }
  }

  // 단골 초대 생성
  Future<bool> createBuddyInvitation({
    required int signalId,
    required int inviteeId,
    String? message,
  }) async {
    try {
      final request = CreateBuddyInvitationRequest(
        signalId: signalId,
        inviteeId: inviteeId,
        message: message,
      );

      await _apiService.createBuddyInvitation(request);
      return true;
    } catch (e) {
      emit(state.copyWith(invitationError: e.toString()));
      return false;
    }
  }

  // 단골 초대 목록 로드
  Future<void> loadBuddyInvitations({
    String? status,
    bool refresh = false,
  }) async {
    if (refresh || state.invitations.isEmpty) {
      emit(state.copyWith(clearInvitationError: true, invitationsPage: 1));
    }

    try {
      final invitations = await _apiService.getBuddyInvitations(
        status: status,
        page: refresh ? 1 : state.invitationsPage,
        limit: _pageSize,
      );

      final newInvitations = refresh ? invitations : [...state.invitations, ...invitations];

      emit(state.copyWith(
        invitations: newInvitations,
        hasMoreInvitations: invitations.length >= _pageSize,
        invitationsPage: refresh ? 2 : state.invitationsPage + 1,
      ));
    } catch (e) {
      emit(state.copyWith(invitationError: e.toString()));
    }
  }

  // 단골 초대 응답
  Future<bool> respondBuddyInvitation(int invitationId, String status) async {
    try {
      await _apiService.respondBuddyInvitation(invitationId, status);
      
      // 초대 목록에서 업데이트
      final updatedInvitations = state.invitations.map((invitation) {
        if (invitation.id == invitationId) {
          return BuddyInvitationModel(
            id: invitation.id,
            signalId: invitation.signalId,
            inviterId: invitation.inviterId,
            inviteeId: invitation.inviteeId,
            status: status,
            message: invitation.message,
            expiresAt: invitation.expiresAt,
            createdAt: invitation.createdAt,
            respondedAt: DateTime.now(),
          );
        }
        return invitation;
      }).toList();

      emit(state.copyWith(invitations: updatedInvitations));
      
      // 수락한 경우 단골 목록 새로고침
      if (status == 'accepted') {
        await refreshBuddies();
        await loadBuddyStats();
      }
      
      return true;
    } catch (e) {
      emit(state.copyWith(invitationError: e.toString()));
      return false;
    }
  }

  // 에러 클리어
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  void clearStatsError() {
    emit(state.copyWith(clearStatsError: true));
  }

  void clearPotentialError() {
    emit(state.copyWith(clearPotentialError: true));
  }

  void clearMannerError() {
    emit(state.copyWith(clearMannerError: true));
  }

  void clearInvitationError() {
    emit(state.copyWith(clearInvitationError: true));
  }
}