import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';
import '../../features/auth/data/services/auth_service.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('deep_link_service');
  
  final AuthService _authService = AuthService();
  StreamSubscription<Uri>? _linkSubscription;
  
  // Callback functions
  Function(String token, bool isNewUser)? onAuthSuccess;
  Function(String error)? onAuthError;
  
  void initialize() {
    _handleInitialLink();
    _handleIncomingLinks();
  }
  
  void dispose() {
    _linkSubscription?.cancel();
  }
  
  // Handle the initial link when app is launched from a link
  Future<void> _handleInitialLink() async {
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _handleLink(initialLink);
      }
    } on PlatformException {
      // Handle exception by ignoring it or logging it
      print('Failed to get initial link');
    }
  }
  
  // Handle incoming links when app is already running
  void _handleIncomingLinks() {
    _linkSubscription = linkStream.listen(
      _handleLink,
      onError: (err) {
        print('Deep link error: $err');
      },
    );
  }
  
  // Process the received link
  void _handleLink(Uri uri) {
    print('Received deep link: $uri');
    
    // Check if this is an auth verification link
    if (uri.path == '/auth/verify') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _handleAuthVerification(token);
      } else {
        onAuthError?.call('Invalid authentication link');
      }
    }
  }
  
  // Handle authentication verification
  Future<void> _handleAuthVerification(String token) async {
    try {
      final response = await _authService.verifyMagicLink(token);
      onAuthSuccess?.call(response.token, response.isNewUser);
    } catch (e) {
      onAuthError?.call(e.toString().replaceAll('Exception: ', ''));
    }
  }
  
  // Set callback functions
  void setAuthCallbacks({
    Function(String token, bool isNewUser)? onSuccess,
    Function(String error)? onError,
  }) {
    onAuthSuccess = onSuccess;
    onAuthError = onError;
  }
}