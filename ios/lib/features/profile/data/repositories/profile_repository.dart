import 'package:dio/dio.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/network_exceptions.dart';

abstract class ProfileRepository {
  Future<ApiResult<ProfileData>> getProfile();
  Future<ApiResult<MinimalProfile>> getMinimalProfile(int userId);
  Future<ApiResult<TrustStats>> getTrustStats();
  Future<ApiResult<void>> quickSetup(QuickSetupRequest request);
  Future<ApiResult<ProfileData>> updateProfile(UpdateProfileRequest request);
  Future<ApiResult<void>> updateMannerTemperature();
}

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileService _profileService;

  ProfileRepositoryImpl(this._profileService);

  @override
  Future<ApiResult<ProfileData>> getProfile() async {
    try {
      final response = await _profileService.getProfile();
      if (response.response.statusCode == 200) {
        return ApiResult.success(response.data);
      } else {
        return ApiResult.failure(NetworkExceptions.defaultError());
      }
    } catch (e) {
      return ApiResult.failure(NetworkExceptions.getDioException(e));
    }
  }

  @override
  Future<ApiResult<MinimalProfile>> getMinimalProfile(int userId) async {
    try {
      final response = await _profileService.getMinimalProfile(userId);
      if (response.response.statusCode == 200) {
        return ApiResult.success(response.data);
      } else {
        return ApiResult.failure(NetworkExceptions.defaultError());
      }
    } catch (e) {
      return ApiResult.failure(NetworkExceptions.getDioException(e));
    }
  }

  @override
  Future<ApiResult<TrustStats>> getTrustStats() async {
    try {
      final response = await _profileService.getTrustStats();
      if (response.response.statusCode == 200) {
        return ApiResult.success(response.data);
      } else {
        return ApiResult.failure(NetworkExceptions.defaultError());
      }
    } catch (e) {
      return ApiResult.failure(NetworkExceptions.getDioException(e));
    }
  }

  @override
  Future<ApiResult<void>> quickSetup(QuickSetupRequest request) async {
    try {
      final response = await _profileService.quickSetup(request);
      if (response.response.statusCode == 200) {
        return const ApiResult.success(null);
      } else {
        return ApiResult.failure(NetworkExceptions.defaultError());
      }
    } catch (e) {
      return ApiResult.failure(NetworkExceptions.getDioException(e));
    }
  }

  @override
  Future<ApiResult<ProfileData>> updateProfile(UpdateProfileRequest request) async {
    try {
      final response = await _profileService.updateProfile(request);
      if (response.response.statusCode == 200) {
        return ApiResult.success(response.data);
      } else {
        return ApiResult.failure(NetworkExceptions.defaultError());
      }
    } catch (e) {
      return ApiResult.failure(NetworkExceptions.getDioException(e));
    }
  }

  @override
  Future<ApiResult<void>> updateMannerTemperature() async {
    try {
      final response = await _profileService.updateMannerTemperature();
      if (response.response.statusCode == 200) {
        return const ApiResult.success(null);
      } else {
        return ApiResult.failure(NetworkExceptions.defaultError());
      }
    } catch (e) {
      return ApiResult.failure(NetworkExceptions.getDioException(e));
    }
  }
}