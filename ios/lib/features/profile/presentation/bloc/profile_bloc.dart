import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/profile_repository.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/network/network_exceptions.dart';

// Events
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
}

class ProfileRequested extends ProfileEvent {
  @override
  List<Object> get props => [];
}

class ProfileUpdated extends ProfileEvent {
  final UpdateProfileRequest request;

  const ProfileUpdated(this.request);

  @override
  List<Object> get props => [request];
}

class TrustStatsRequested extends ProfileEvent {
  @override
  List<Object> get props => [];
}

class MannerTemperatureUpdateRequested extends ProfileEvent {
  @override
  List<Object> get props => [];
}

class ProfileQuickSetupRequested extends ProfileEvent {
  final QuickSetupRequest request;

  const ProfileQuickSetupRequested(this.request);

  @override
  List<Object> get props => [request];
}

// States
abstract class ProfileState extends Equatable {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  @override
  List<Object> get props => [];
}

class ProfileLoading extends ProfileState {
  @override
  List<Object> get props => [];
}

class ProfileLoaded extends ProfileState {
  final ProfileData profile;
  final TrustStats? trustStats;

  const ProfileLoaded({
    required this.profile,
    this.trustStats,
  });

  @override
  List<Object?> get props => [profile, trustStats];

  ProfileLoaded copyWith({
    ProfileData? profile,
    TrustStats? trustStats,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      trustStats: trustStats ?? this.trustStats,
    );
  }
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}

class ProfileUpdating extends ProfileState {
  @override
  List<Object> get props => [];
}

class ProfileUpdateSuccess extends ProfileState {
  final ProfileData profile;

  const ProfileUpdateSuccess(this.profile);

  @override
  List<Object> get props => [profile];
}

class ProfileUpdateFailure extends ProfileState {
  final String message;

  const ProfileUpdateFailure(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;

  ProfileBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(ProfileInitial()) {
    
    on<ProfileRequested>(_onProfileRequested);
    on<ProfileUpdated>(_onProfileUpdated);
    on<TrustStatsRequested>(_onTrustStatsRequested);
    on<MannerTemperatureUpdateRequested>(_onMannerTemperatureUpdateRequested);
    on<ProfileQuickSetupRequested>(_onProfileQuickSetupRequested);
  }

  Future<void> _onProfileRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());

    final result = await _profileRepository.getProfile();
    
    result.when(
      success: (profile) async {
        // Also get trust stats
        final trustStatsResult = await _profileRepository.getTrustStats();
        trustStatsResult.when(
          success: (trustStats) {
            emit(ProfileLoaded(profile: profile, trustStats: trustStats));
          },
          failure: (error) {
            // Still show profile even if trust stats fail
            emit(ProfileLoaded(profile: profile));
          },
        );
      },
      failure: (error) {
        emit(ProfileError(NetworkExceptions.getErrorMessage(error)));
      },
    );
  }

  Future<void> _onProfileUpdated(
    ProfileUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(ProfileUpdating());
      
      final result = await _profileRepository.updateProfile(event.request);
      
      result.when(
        success: (profile) {
          emit(ProfileUpdateSuccess(profile));
          // Reload profile to get latest data
          add(ProfileRequested());
        },
        failure: (error) {
          emit(ProfileUpdateFailure(NetworkExceptions.getErrorMessage(error)));
          // Restore previous state
          emit(currentState);
        },
      );
    }
  }

  Future<void> _onTrustStatsRequested(
    TrustStatsRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      final result = await _profileRepository.getTrustStats();
      
      result.when(
        success: (trustStats) {
          emit(currentState.copyWith(trustStats: trustStats));
        },
        failure: (error) {
          // Keep current state if trust stats fail
          emit(ProfileError(NetworkExceptions.getErrorMessage(error)));
        },
      );
    }
  }

  Future<void> _onMannerTemperatureUpdateRequested(
    MannerTemperatureUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      final result = await _profileRepository.updateMannerTemperature();
      
      result.when(
        success: (_) {
          // Reload profile to get updated temperature
          add(ProfileRequested());
        },
        failure: (error) {
          emit(ProfileError(NetworkExceptions.getErrorMessage(error)));
        },
      );
    }
  }

  Future<void> _onProfileQuickSetupRequested(
    ProfileQuickSetupRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());

    final result = await _profileRepository.quickSetup(event.request);
    
    result.when(
      success: (_) {
        // Reload profile after successful setup
        add(ProfileRequested());
      },
      failure: (error) {
        emit(ProfileError(NetworkExceptions.getErrorMessage(error)));
      },
    );
  }
}