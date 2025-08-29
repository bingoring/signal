import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:signal_app/features/signal/domain/entities/signal.dart';
import 'package:signal_app/features/signal/domain/usecases/update_signal_usecase.dart';
import 'package:signal_app/core/error/failures.dart';

part 'signal_edit_state.dart';

class SignalEditCubit extends Cubit<SignalEditState> {
  final UpdateSignalUseCase updateSignalUseCase;

  SignalEditCubit({
    required this.updateSignalUseCase,
  }) : super(SignalEditState.initial());

  void initializeWithSignal(Signal signal) {
    emit(SignalEditState.fromSignal(signal));
  }

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

  void updateLocation(double latitude, double longitude, String address) {
    emit(state.copyWith(
      latitude: latitude,
      longitude: longitude,
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

  Future<void> saveSignal() async {
    if (!_validateForm()) return;

    emit(state.copyWith(status: SignalEditStatus.loading));

    final updateParams = UpdateSignalParams(
      signalId: state.originalSignal!.id,
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
      final result = await updateSignalUseCase(updateParams);
      
      result.fold(
        (failure) {
          emit(state.copyWith(
            status: SignalEditStatus.failure,
            errorMessage: _mapFailureToMessage(failure),
          ));
        },
        (updatedSignal) {
          emit(state.copyWith(
            status: SignalEditStatus.success,
            successMessage: '시그널이 성공적으로 수정되었습니다.',
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SignalEditStatus.failure,
        errorMessage: '시그널 수정 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  bool _validateForm() {
    final errors = <String>[];

    if (state.category.isEmpty) {
      errors.add('카테고리를 선택해주세요');
    }

    if (state.title.trim().isEmpty) {
      errors.add('제목을 입력해주세요');
    } else if (state.title.trim().length < 5) {
      errors.add('제목은 5자 이상 입력해주세요');
    }

    if (state.description.trim().isEmpty) {
      errors.add('설명을 입력해주세요');
    } else if (state.description.trim().length < 10) {
      errors.add('설명은 10자 이상 입력해주세요');
    }

    if (state.scheduledAt == null) {
      errors.add('모임 일시를 선택해주세요');
    } else if (state.scheduledAt!.isBefore(DateTime.now())) {
      errors.add('미래 시간을 선택해주세요');
    }

    if (state.maxParticipants < 2) {
      errors.add('최소 2명 이상의 참여자가 필요합니다');
    }

    if (state.latitude == 0.0 || state.longitude == 0.0) {
      errors.add('위치를 선택해주세요');
    }

    if (state.address.isEmpty) {
      errors.add('주소 정보를 확인해주세요');
    }

    if (state.minAge >= state.maxAge) {
      errors.add('올바른 연령대를 설정해주세요');
    }

    if (errors.isNotEmpty) {
      emit(state.copyWith(
        status: SignalEditStatus.failure,
        errorMessage: errors.first,
      ));
      return false;
    }

    return true;
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      case NetworkFailure:
        return '네트워크 연결을 확인해주세요.';
      case ValidationFailure:
        return (failure as ValidationFailure).message;
      case UnauthorizedFailure:
        return '시그널을 수정할 권한이 없습니다.';
      case NotFoundFailure:
        return '시그널을 찾을 수 없습니다.';
      default:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }

  void clearError() {
    emit(state.copyWith(
      status: SignalEditStatus.editing,
      errorMessage: '',
    ));
  }
}

class UpdateSignalParams {
  final String signalId;
  final String title;
  final String description;
  final String category;
  final DateTime scheduledAt;
  final double latitude;
  final double longitude;
  final String address;
  final int maxParticipants;
  final int minAge;
  final int maxAge;
  final String genderPreference;
  final bool requiresApproval;
  final bool isPrivate;

  UpdateSignalParams({
    required this.signalId,
    required this.title,
    required this.description,
    required this.category,
    required this.scheduledAt,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.maxParticipants,
    required this.minAge,
    required this.maxAge,
    required this.genderPreference,
    required this.requiresApproval,
    required this.isPrivate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'scheduled_at': scheduledAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'max_participants': maxParticipants,
      'min_age': minAge,
      'max_age': maxAge,
      'gender_preference': genderPreference,
      'requires_approval': requiresApproval,
      'is_private': isPrivate,
    };
  }
}