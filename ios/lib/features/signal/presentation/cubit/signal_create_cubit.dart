import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:signal_app/features/signal/domain/entities/signal.dart';
import 'package:signal_app/features/signal/domain/usecases/create_signal_usecase.dart';
import 'package:signal_app/core/error/failures.dart';

part 'signal_create_state.dart';

class SignalCreateCubit extends Cubit<SignalCreateState> {
  final CreateSignalUseCase createSignalUseCase;

  SignalCreateCubit({
    required this.createSignalUseCase,
  }) : super(SignalCreateState.initial());

  void updateCategory(String category) {
    emit(state.copyWith(category: category));
  }

  void updateTitle(String title) {
    emit(state.copyWith(title: title));
  }

  void updateDescription(String description) {
    emit(state.copyWith(description: description));
  }

  void updateScheduledAt(DateTime scheduledAt) {
    emit(state.copyWith(scheduledAt: scheduledAt));
  }

  void updateMaxParticipants(int maxParticipants) {
    emit(state.copyWith(maxParticipants: maxParticipants));
  }

  void updateLocation(LatLng location, String address) {
    emit(state.copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
      address: address,
    ));
  }

  void updateAgeRange(int minAge, int maxAge) {
    emit(state.copyWith(
      minAge: minAge,
      maxAge: maxAge,
    ));
  }

  void updateGenderPreference(String genderPreference) {
    emit(state.copyWith(genderPreference: genderPreference));
  }

  void updateRequiresApproval(bool requiresApproval) {
    emit(state.copyWith(requiresApproval: requiresApproval));
  }

  void updatePrivacy(bool isPrivate) {
    emit(state.copyWith(isPrivate: isPrivate));
  }

  void nextStep() {
    if (state.currentStep < 3) {
      emit(state.copyWith(currentStep: state.currentStep + 1));
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      emit(state.copyWith(currentStep: state.currentStep - 1));
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 3) {
      emit(state.copyWith(currentStep: step));
    }
  }

  bool canProceedToNextStep() {
    switch (state.currentStep) {
      case 0: // Category step
        return state.category.isNotEmpty;
      case 1: // Details step
        return state.title.isNotEmpty &&
               state.description.isNotEmpty &&
               state.scheduledAt != null &&
               state.maxParticipants > 0;
      case 2: // Location step
        return state.latitude != 0.0 &&
               state.longitude != 0.0 &&
               state.address.isNotEmpty;
      case 3: // Settings step
        return true;
      default:
        return false;
    }
  }

  String? getStepError() {
    switch (state.currentStep) {
      case 0:
        if (state.category.isEmpty) return '카테고리를 선택해주세요';
        break;
      case 1:
        if (state.title.isEmpty) return '제목을 입력해주세요';
        if (state.description.isEmpty) return '설명을 입력해주세요';
        if (state.scheduledAt == null) return '일시를 선택해주세요';
        if (state.maxParticipants <= 0) return '참여 인원을 설정해주세요';
        if (state.scheduledAt != null && state.scheduledAt!.isBefore(DateTime.now())) {
          return '미래 시간을 선택해주세요';
        }
        break;
      case 2:
        if (state.latitude == 0.0 || state.longitude == 0.0) return '위치를 선택해주세요';
        if (state.address.isEmpty) return '주소 정보를 확인해주세요';
        break;
      case 3:
        if (state.minAge >= state.maxAge) return '올바른 연령대를 설정해주세요';
        break;
    }
    return null;
  }

  Future<void> createSignal() async {
    if (!_validateAllSteps()) {
      emit(state.copyWith(
        status: SignalCreateStatus.failure,
        errorMessage: '모든 필수 정보를 입력해주세요',
      ));
      return;
    }

    emit(state.copyWith(status: SignalCreateStatus.loading));

    final signalData = CreateSignalParams(
      title: state.title,
      description: state.description,
      category: state.category,
      scheduledAt: state.scheduledAt!,
      latitude: state.latitude,
      longitude: state.longitude,
      address: state.address,
      maxParticipants: state.maxParticipants,
      minAge: state.minAge,
      maxAge: state.maxAge,
      genderPreference: state.genderPreference,
      requiresApproval: state.requiresApproval,
      isPrivate: state.isPrivate,
    );

    try {
      final result = await createSignalUseCase(signalData);
      
      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalCreateStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (signal) {
          emit(state.copyWith(
            status: SignalCreateStatus.success,
            createdSignal: signal,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalCreateStatus.failure,
        errorMessage: '시그널 생성 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  bool _validateAllSteps() {
    return state.category.isNotEmpty &&
           state.title.isNotEmpty &&
           state.description.isNotEmpty &&
           state.scheduledAt != null &&
           state.scheduledAt!.isAfter(DateTime.now()) &&
           state.maxParticipants > 0 &&
           state.latitude != 0.0 &&
           state.longitude != 0.0 &&
           state.address.isNotEmpty &&
           state.minAge < state.maxAge &&
           state.minAge >= 18 &&
           state.maxAge <= 65;
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      case NetworkFailure:
        return '네트워크 연결을 확인해주세요.';
      case ValidationFailure:
        return (failure as ValidationFailure).message;
      default:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }

  void resetForm() {
    emit(SignalCreateState.initial());
  }

  void clearError() {
    emit(state.copyWith(
      status: SignalCreateStatus.initial,
      errorMessage: '',
    ));
  }
}