import 'dart:convert';
import 'package:dio/dio.dart';

import '../models/signal_model.dart';
import 'signal_api_service.dart';

class SignalService {
  final SignalApiService _apiService;

  SignalService(this._apiService);

  /// 근처 시그널 조회 (위치 기반)
  Future<List<SignalWithDistance>> getNearbySignals({
    required double latitude,
    required double longitude,
    double radius = 5000,
    List<String>? categories,
  }) async {
    try {
      final categoriesQuery = categories?.join(',');
      
      final response = await _apiService.getNearbySignals(
        latitude,
        longitude,
        radius,
        categoriesQuery,
      );

      if (response.success && response.data != null) {
        // Backend의 GetNearbySignals 응답 구조에 맞게 파싱
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null && responseData['signals'] != null) {
          final signalsJson = responseData['signals'] as List;
          return signalsJson
              .map((json) => SignalWithDistance.fromJson(json))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      throw Exception('근처 시그널 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 시그널 검색 (텍스트 기반)
  Future<List<SignalWithDistance>> searchSignals({
    required String query,
    double? latitude,
    double? longitude,
    double? radius,
    String? category,
    DateTime? startTime,
    DateTime? endTime,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.searchSignals(
        latitude,
        longitude,
        radius,
        category,
        startTime?.toIso8601String(),
        endTime?.toIso8601String(),
        page,
        limit,
      );

      if (response.success && response.data != null) {
        final signalsJson = response.data as List;
        return signalsJson
            .map((json) => SignalWithDistance.fromJson(json))
            .toList();
      }
      
      return [];
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      throw Exception('시그널 검색 중 오류가 발생했습니다: $e');
    }
  }

  /// 시그널 상세 조회
  Future<Signal> getSignal(int signalId) async {
    try {
      final response = await _apiService.getSignal(signalId);
      
      if (response.success && response.data != null) {
        return Signal.fromJson(response.data as Map<String, dynamic>);
      }
      
      throw Exception('시그널을 찾을 수 없습니다');
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      throw Exception('시그널 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 시그널 생성
  Future<Signal> createSignal(CreateSignalRequest request) async {
    try {
      final response = await _apiService.createSignal(request);
      
      if (response.success && response.data != null) {
        return Signal.fromJson(response.data as Map<String, dynamic>);
      }
      
      throw Exception('시그널 생성에 실패했습니다');
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      throw Exception('시그널 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// 시그널 참여
  Future<void> joinSignal(int signalId, {String? message}) async {
    try {
      final request = JoinSignalRequest(message: message);
      final response = await _apiService.joinSignal(signalId, request);
      
      if (!response.success) {
        throw Exception(response.message);
      }
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      throw Exception('시그널 참여 중 오류가 발생했습니다: $e');
    }
  }

  /// 시그널 나가기
  Future<void> leaveSignal(int signalId) async {
    try {
      final response = await _apiService.leaveSignal(signalId);
      
      if (!response.success) {
        throw Exception(response.message);
      }
    } catch (e) {
      if (e is DioException) {
        throw _handleDioError(e);
      }
      throw Exception('시그널 나가기 중 오류가 발생했습니다: $e');
    }
  }

  /// DioException 처리
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('네트워크 연결이 불안정합니다. 다시 시도해 주세요.');
        
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        
        if (statusCode == 400) {
          if (responseData is Map && responseData['message'] != null) {
            return Exception(responseData['message']);
          }
          return Exception('잘못된 요청입니다.');
        } else if (statusCode == 401) {
          return Exception('인증이 필요합니다. 다시 로그인해 주세요.');
        } else if (statusCode == 403) {
          return Exception('권한이 없습니다.');
        } else if (statusCode == 404) {
          return Exception('요청한 시그널을 찾을 수 없습니다.');
        } else if (statusCode == 500) {
          return Exception('서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
        }
        
        return Exception('서버와의 통신 중 오류가 발생했습니다 (${statusCode})');
        
      case DioExceptionType.cancel:
        return Exception('요청이 취소되었습니다.');
        
      case DioExceptionType.connectionError:
        return Exception('네트워크에 연결할 수 없습니다. 인터넷 연결을 확인해 주세요.');
        
      default:
        return Exception('알 수 없는 오류가 발생했습니다: ${e.message}');
    }
  }

  /// 시그널 상태 변환
  String getSignalStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return '모집 중';
      case 'full':
        return '정원 마감';
      case 'closed':
        return '마감됨';
      case 'cancelled':
        return '취소됨';
      case 'completed':
        return '완료됨';
      default:
        return '알 수 없음';
    }
  }

  /// 카테고리 한국어 변환
  String getCategoryText(String category) {
    switch (category.toLowerCase()) {
      case 'sports':
        return '스포츠';
      case 'food':
        return '맛집';
      case 'culture':
        return '문화';
      case 'study':
        return '스터디';
      case 'hobby':
        return '취미';
      case 'travel':
        return '여행';
      case 'shopping':
        return '쇼핑';
      case 'entertainment':
        return '엔터테인먼트';
      default:
        return category;
    }
  }

  /// 거리 포맷팅
  String formatDistance(double? distance) {
    if (distance == null) return '';
    
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 시간 포맷팅
  String formatScheduledTime(DateTime scheduledAt) {
    final now = DateTime.now();
    final difference = scheduledAt.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}일 후';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 후';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 후';
    } else if (difference.inMinutes > -60) {
      return '진행 중';
    } else {
      return '종료됨';
    }
  }
}