import 'package:flutter/material.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../data/services/auth_service.dart';
import '../../../../core/services/deep_link_service.dart';
import 'magic_link_page.dart';
import 'welcome_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final DeepLinkService _deepLinkService = DeepLinkService();
  
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isNewUser = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _setupDeepLinkCallbacks();
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  void _setupDeepLinkCallbacks() {
    _deepLinkService.setAuthCallbacks(
      onSuccess: (token, isNewUser) {
        setState(() {
          _isAuthenticated = true;
          _isNewUser = isNewUser;
        });
        
        _showWelcomeIfNewUser();
      },
      onError: (error) {
        _showErrorSnackBar(error);
      },
    );
    
    _deepLinkService.initialize();
  }

  void _showWelcomeIfNewUser() {
    if (_isNewUser) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const WelcomePage(),
        ),
      );
    }
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Signal 로딩 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      return const HomePage();
    } else {
      return const MagicLinkPage();
    }
  }
}