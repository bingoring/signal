import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/buddy_model.dart';

@lazySingleton
class BuddyApiService {
  final Dio _dio;

  BuddyApiService(this._dio);

  // 단골 목록 조회
  Future<List<BuddyModel>> getBuddies({
    String? status,
    String sortBy = 'last_interaction',
    String sortOrder = 'desc',
    double? minCompatibility,
    int? minInteractions,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'limit': limit,
    };

    if (status != null) queryParams['status'] = status;
    if (minCompatibility != null) queryParams['min_compatibility'] = minCompatibility;
    if (minInteractions != null) queryParams['min_interactions'] = minInteractions;

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/buddies',
      queryParameters: queryParams,
    );

    final List<dynamic> data = response.data['data'];
    return data.map((json) => BuddyModel.fromJson(json)).toList();
  }

  // 특정 단골 관계 조회
  Future<BuddyModel> getBuddy(int buddyId) async {
    final response = await _dio.get('${ApiConstants.baseUrl}/buddies/$buddyId');
    return BuddyModel.fromJson(response.data['data']);
  }

  // 단골 관계 생성
  Future<BuddyModel> createBuddy(CreateBuddyRequest request) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/buddies',
      data: request.toJson(),
    );
    return BuddyModel.fromJson(response.data['data']);
  }

  // 단골 관계 수정
  Future<void> updateBuddy(
    int buddyId, {
    String? status,
    double? compatibilityScore,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (status != null) data['status'] = status;
    if (compatibilityScore != null) data['compatibility_score'] = compatibilityScore;
    if (notes != null) data['notes'] = notes;

    await _dio.put(
      '${ApiConstants.baseUrl}/buddies/$buddyId',
      data: data,
    );
  }

  // 단골 관계 삭제
  Future<void> deleteBuddy(int buddyId) async {
    await _dio.delete('${ApiConstants.baseUrl}/buddies/$buddyId');
  }

  // 단골 후보자 조회
  Future<List<PotentialBuddyModel>> getPotentialBuddies({
    int minInteractions = 2,
    double minMannerScore = 4.0,
  }) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/buddies/potential',
      queryParameters: {
        'min_interactions': minInteractions,
        'min_manner_score': minMannerScore,
      },
    );

    final List<dynamic> data = response.data['data'];
    return data.map((json) => PotentialBuddyModel.fromJson(json)).toList();
  }

  // 단골 통계 조회
  Future<BuddyStatsModel> getBuddyStats() async {
    final response = await _dio.get('${ApiConstants.baseUrl}/buddies/stats');
    return BuddyStatsModel.fromJson(response.data['data']);
  }

  // 매너 점수 평가
  Future<MannerLogModel> createMannerLog(CreateMannerLogRequest request) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/buddies/manner',
      data: request.toJson(),
    );
    return MannerLogModel.fromJson(response.data['data']);
  }

  // 매너 점수 이력 조회
  Future<List<MannerLogModel>> getMannerLogs({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/buddies/manner/logs',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    final List<dynamic> data = response.data['data'];
    return data.map((json) => MannerLogModel.fromJson(json)).toList();
  }

  // 단골 초대 생성
  Future<BuddyInvitationModel> createBuddyInvitation(CreateBuddyInvitationRequest request) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}/buddies/invitations',
      data: request.toJson(),
    );
    return BuddyInvitationModel.fromJson(response.data['data']);
  }

  // 단골 초대 목록 조회
  Future<List<BuddyInvitationModel>> getBuddyInvitations({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (status != null) queryParams['status'] = status;

    final response = await _dio.get(
      '${ApiConstants.baseUrl}/buddies/invitations',
      queryParameters: queryParams,
    );

    final List<dynamic> data = response.data['data'];
    return data.map((json) => BuddyInvitationModel.fromJson(json)).toList();
  }

  // 단골 초대 응답
  Future<void> respondBuddyInvitation(int invitationId, String status) async {
    await _dio.post(
      '${ApiConstants.baseUrl}/buddies/invitations/$invitationId/respond',
      data: {'status': status},
    );
  }
}