import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../models/signal_model.dart';

part 'signal_api_service.g.dart';

@RestApi(baseUrl: 'http://localhost:8080/api/v1') // TODO: 환경별 설정
abstract class SignalApiService {
  factory SignalApiService(Dio dio, {String baseUrl}) = _SignalApiService;

  /// 근처 시그널 조회
  @GET('/signals/nearby')
  Future<ApiResponse<List<SignalModel>>> getNearbySignals(
    @Query('lat') double latitude,
    @Query('lon') double longitude,
    @Query('radius') double radius,
    @Query('categories') String? categories,
  );

  /// 시그널 검색
  @GET('/signals')
  Future<ApiResponse<List<SignalModel>>> searchSignals(
    @Query('latitude') double? latitude,
    @Query('longitude') double? longitude,
    @Query('radius') double? radius,
    @Query('category') String? category,
    @Query('start_time') String? startTime,
    @Query('end_time') String? endTime,
    @Query('page') int? page,
    @Query('limit') int? limit,
  );

  /// 시그널 상세 조회
  @GET('/signals/{id}')
  Future<ApiResponse<SignalModel>> getSignal(@Path('id') int signalId);

  /// 시그널 생성
  @POST('/signals')
  Future<ApiResponse<SignalModel>> createSignal(
    @Body() CreateSignalRequest request,
  );

  /// 시그널 참여
  @POST('/signals/{id}/join')
  Future<ApiResponse<dynamic>> joinSignal(
    @Path('id') int signalId,
    @Body() JoinSignalRequest request,
  );

  /// 시그널 나가기
  @POST('/signals/{id}/leave')
  Future<ApiResponse<dynamic>> leaveSignal(@Path('id') int signalId);
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? total;
  final int? page;
  final int? limit;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.total,
    this.page,
    this.limit,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      total: json['total'],
      page: json['page'],
      limit: json['limit'],
    );
  }
}

class CreateSignalRequest {
  final String title;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String address;
  final String? placeName;
  final DateTime scheduledAt;
  final int maxParticipants;
  final int? minAge;
  final int? maxAge;
  final bool allowInstantJoin;
  final bool requireApproval;
  final String? genderPreference;

  CreateSignalRequest({
    required this.title,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeName,
    required this.scheduledAt,
    required this.maxParticipants,
    this.minAge,
    this.maxAge,
    required this.allowInstantJoin,
    required this.requireApproval,
    this.genderPreference,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'place_name': placeName,
      'scheduled_at': scheduledAt.toIso8601String(),
      'max_participants': maxParticipants,
      'min_age': minAge,
      'max_age': maxAge,
      'allow_instant_join': allowInstantJoin,
      'require_approval': requireApproval,
      'gender_preference': genderPreference,
    };
  }
}

class JoinSignalRequest {
  final String? message;

  JoinSignalRequest({this.message});

  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }
}