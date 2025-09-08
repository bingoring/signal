import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';

class AuthService {
  static const String _baseUrl = 'http://localhost:8080/api/v1';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_profile';
  
  // Send magic link to email
  Future<AuthResponse> sendMagicLink(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/magic-link'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({'email': email}),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AuthResponse(
        message: data['message'] ?? '매직링크가 전송되었습니다.',
        success: data['success'] ?? true,
      );
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? '매직링크 전송에 실패했습니다.');
    }
  }
  
  // Verify magic link token
  Future<TokenVerifyResponse> verifyMagicLink(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/verify?token=$token'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Save token and user data
      await _saveAuthData(
        data['token'],
        data['user'],
      );
      
      return TokenVerifyResponse(
        token: data['token'],
        isNewUser: data['is_new_user'] ?? false,
        user: UserProfile.fromJson(data['user']),
      );
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? '인증에 실패했습니다.');
    }
  }
  
  // Get current user profile
  Future<UserProfile?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProfile.fromJson(data['user']);
      }
      return null;
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }
  
  // Logout user
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      await _clearAuthData();
    }
  }
  
  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null) return false;
    
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      return false;
    }
  }
  
  // Get stored auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  // Get stored user profile
  Future<UserProfile?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return UserProfile.fromJson(json.decode(userJson));
    }
    return null;
  }
  
  // Save authentication data
  Future<void> _saveAuthData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, json.encode(userData));
  }
  
  // Clear authentication data
  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}