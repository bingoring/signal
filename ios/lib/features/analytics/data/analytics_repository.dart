import 'package:dio/dio.dart';
import '../models/user_analytics.dart';
import '../models/achievement.dart';

class AnalyticsRepository {
  final Dio _dio;

  AnalyticsRepository({required Dio dio}) : _dio = dio;

  /// 사용자 분석 데이터 조회
  Future<UserAnalytics> getUserAnalytics(int userId, {String? week}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (week != null) {
        queryParams['week'] = week;
      }

      final response = await _dio.get(
        '/analytics/user/$userId',
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        return UserAnalytics.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to get user analytics');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// 사용자 분석 이력 조회
  Future<List<UserAnalytics>> getUserAnalyticsHistory(
    int userId, {
    int weeks = 4,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/user/$userId/history',
        queryParameters: {'weeks': weeks},
      );

      if (response.data['success'] == true) {
        final List<dynamic> historyData = response.data['data']['history'];
        return historyData
            .map((json) => UserAnalytics.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to get analytics history');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// 사용자 업적 조회
  Future<AchievementData> getUserAchievements(int userId) async {
    try {
      final response = await _dio.get('/analytics/user/$userId/achievements');

      if (response.data['success'] == true) {
        return AchievementData.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to get user achievements');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// 분석 요약 정보 조회
  Future<AnalyticsSummary> getAnalyticsSummary(int userId) async {
    try {
      final response = await _dio.get('/analytics/user/$userId/summary');

      if (response.data['success'] == true) {
        return AnalyticsSummary.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to get analytics summary');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// 분석 데이터 재생성
  Future<UserAnalytics> regenerateAnalytics(
    int userId, {
    String? week,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (week != null) {
        queryParams['week'] = week;
      }

      final response = await _dio.post(
        '/analytics/user/$userId/regenerate',
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        return UserAnalytics.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to regenerate analytics');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}