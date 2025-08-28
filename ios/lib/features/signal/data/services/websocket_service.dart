import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/signal_model.dart';

class WebSocketService {
  static const String _baseUrl = 'ws://localhost:8080'; // TODO: 환경별 설정
  WebSocketChannel? _channel;
  StreamController<SignalUpdateModel>? _signalUpdateController;
  Timer? _pingTimer;
  bool _isConnected = false;

  Stream<SignalUpdateModel> get signalUpdates => 
      _signalUpdateController?.stream ?? const Stream.empty();

  bool get isConnected => _isConnected;

  /// WebSocket 연결 시작
  Future<void> connect(String token) async {
    try {
      await disconnect(); // 기존 연결 정리

      _signalUpdateController = StreamController<SignalUpdateModel>.broadcast();
      
      final uri = Uri.parse('$_baseUrl/api/v1/signals/ws');
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      _isConnected = true;
      _startPingTimer();

      // 메시지 수신 처리
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      print('WebSocket 연결 성공');
    } catch (e) {
      print('WebSocket 연결 실패: $e');
      _isConnected = false;
      rethrow;
    }
  }

  /// 위치 업데이트 전송
  void updateLocation(double latitude, double longitude, double radius) {
    if (_isConnected && _channel != null) {
      final message = {
        'type': 'location_update',
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
      };
      
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// 메시지 처리
  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> json = jsonDecode(data);
      final update = SignalUpdateModel.fromJson(json);
      _signalUpdateController?.add(update);
    } catch (e) {
      print('WebSocket 메시지 파싱 오류: $e');
    }
  }

  /// 오류 처리
  void _handleError(dynamic error) {
    print('WebSocket 오류: $error');
    _isConnected = false;
  }

  /// 연결 종료 처리
  void _handleDisconnect() {
    print('WebSocket 연결 끊김');
    _isConnected = false;
    _pingTimer?.cancel();
  }

  /// Ping 타이머 시작 (연결 유지)
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          print('Ping 전송 실패: $e');
          timer.cancel();
        }
      }
    });
  }

  /// 연결 해제
  Future<void> disconnect() async {
    _isConnected = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    await _signalUpdateController?.close();
    _signalUpdateController = null;
    
    print('WebSocket 연결 해제');
  }

  /// 재연결 시도
  Future<void> reconnect(String token) async {
    if (!_isConnected) {
      await Future.delayed(const Duration(seconds: 2));
      await connect(token);
    }
  }
}