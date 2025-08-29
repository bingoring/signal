import 'package:equatable/equatable.dart';

import '../../data/models/buddy_model.dart';

class BuddyState extends Equatable {
  final bool isLoading;
  final bool isLoadingStats;
  final List<BuddyModel> buddies;
  final List<PotentialBuddyModel> potentialBuddies;
  final List<MannerLogModel> mannerLogs;
  final List<BuddyInvitationModel> invitations;
  final BuddyStatsModel? stats;
  final String? error;
  final String? statsError;
  final String? potentialError;
  final String? mannerError;
  final String? invitationError;
  final bool hasMoreBuddies;
  final bool hasMoreLogs;
  final bool hasMoreInvitations;
  final int currentPage;
  final int logsPage;
  final int invitationsPage;
  final Map<String, dynamic>? currentFilters;

  const BuddyState({
    this.isLoading = false,
    this.isLoadingStats = false,
    this.buddies = const [],
    this.potentialBuddies = const [],
    this.mannerLogs = const [],
    this.invitations = const [],
    this.stats,
    this.error,
    this.statsError,
    this.potentialError,
    this.mannerError,
    this.invitationError,
    this.hasMoreBuddies = true,
    this.hasMoreLogs = true,
    this.hasMoreInvitations = true,
    this.currentPage = 1,
    this.logsPage = 1,
    this.invitationsPage = 1,
    this.currentFilters,
  });

  BuddyState copyWith({
    bool? isLoading,
    bool? isLoadingStats,
    List<BuddyModel>? buddies,
    List<PotentialBuddyModel>? potentialBuddies,
    List<MannerLogModel>? mannerLogs,
    List<BuddyInvitationModel>? invitations,
    BuddyStatsModel? stats,
    String? error,
    String? statsError,
    String? potentialError,
    String? mannerError,
    String? invitationError,
    bool? hasMoreBuddies,
    bool? hasMoreLogs,
    bool? hasMoreInvitations,
    int? currentPage,
    int? logsPage,
    int? invitationsPage,
    Map<String, dynamic>? currentFilters,
    bool clearError = false,
    bool clearStatsError = false,
    bool clearPotentialError = false,
    bool clearMannerError = false,
    bool clearInvitationError = false,
  }) {
    return BuddyState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      buddies: buddies ?? this.buddies,
      potentialBuddies: potentialBuddies ?? this.potentialBuddies,
      mannerLogs: mannerLogs ?? this.mannerLogs,
      invitations: invitations ?? this.invitations,
      stats: stats ?? this.stats,
      error: clearError ? null : (error ?? this.error),
      statsError: clearStatsError ? null : (statsError ?? this.statsError),
      potentialError: clearPotentialError ? null : (potentialError ?? this.potentialError),
      mannerError: clearMannerError ? null : (mannerError ?? this.mannerError),
      invitationError: clearInvitationError ? null : (invitationError ?? this.invitationError),
      hasMoreBuddies: hasMoreBuddies ?? this.hasMoreBuddies,
      hasMoreLogs: hasMoreLogs ?? this.hasMoreLogs,
      hasMoreInvitations: hasMoreInvitations ?? this.hasMoreInvitations,
      currentPage: currentPage ?? this.currentPage,
      logsPage: logsPage ?? this.logsPage,
      invitationsPage: invitationsPage ?? this.invitationsPage,
      currentFilters: currentFilters ?? this.currentFilters,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isLoadingStats,
        buddies,
        potentialBuddies,
        mannerLogs,
        invitations,
        stats,
        error,
        statsError,
        potentialError,
        mannerError,
        invitationError,
        hasMoreBuddies,
        hasMoreLogs,
        hasMoreInvitations,
        currentPage,
        logsPage,
        invitationsPage,
        currentFilters,
      ];
}