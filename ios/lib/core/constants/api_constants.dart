class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://localhost:8080/api/v1';
  
  // Auth Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  
  // User Endpoints
  static const String profile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String updateLocation = '/user/location';
  static const String updateInterests = '/user/interests';
  static const String registerPushToken = '/user/push-token';
  
  // Signal Endpoints
  static const String signals = '/signals';
  static const String mySignals = '/signals/my';
  static const String joinSignal = '/signals/{id}/join';
  static const String leaveSignal = '/signals/{id}/leave';
  static const String approveParticipant = '/signals/{id}/approve/{user_id}';
  
  // Chat Endpoints
  static const String chatRooms = '/chat/rooms';
  static const String messages = '/chat/rooms/{id}/messages';
  static const String sendMessage = '/chat/rooms/{id}/messages';
  static const String websocket = '/chat/ws/{room_id}';
  
  // Rating Endpoints
  static const String rateUser = '/ratings';
  static const String reportUser = '/ratings/report';
}