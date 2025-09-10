import 'package:flutter/material.dart';

class ChatColors {
  // Instagram-inspired color palette
  static const Color primary = Color(0xFF405DE6);
  static const Color secondary = Color(0xFF833AB4);
  static const Color tertiary = Color(0xFFC13584);
  static const Color accent = Color(0xFFFD1D1D);
  
  // Message colors
  static const Color myMessage = Color(0xFF405DE6);
  static const Color otherMessage = Color(0xFFF5F5F5);
  static const Color systemMessage = Color(0xFFE3F2FD);
  static const Color quickReplyBackground = Color(0xFFFF6B6B);
  static const Color locationBackground = Color(0xFF4ECDC4);
  
  // Status colors
  static const Color online = Color(0xFF4CAF50);
  static const Color away = Color(0xFFFF9800);
  static const Color offline = Color(0xFF9E9E9E);
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;
  
  // Background colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);
  
  // Instagram gradient
  static const LinearGradient instagramGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF405DE6),
      Color(0xFF5851DB),
      Color(0xFF833AB4),
      Color(0xFFC13584),
      Color(0xFFE1306C),
      Color(0xFFFD1D1D),
      Color(0xFFF56040),
      Color(0xFFF77737),
      Color(0xFFFCAF45),
      Color(0xFFFFDC80),
    ],
  );
}

class ChatDimensions {
  // Spacing
  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 24.0;
  static const double paddingXL = 32.0;
  
  // Border radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 18.0;
  static const double radiusXL = 24.0;
  
  // Message bubble
  static const EdgeInsets messagePadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );
  static const BorderRadius messageBubbleRadius = BorderRadius.all(
    Radius.circular(18.0),
  );
  
  // Avatar sizes
  static const double avatarSM = 24.0;
  static const double avatarMD = 32.0;
  static const double avatarLG = 48.0;
  static const double avatarXL = 64.0;
  
  // Quick action
  static const double quickActionSize = 44.0;
  static const double quickActionIconSize = 24.0;
  
  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
}

class ChatTextStyles {
  // Message text styles
  static const TextStyle messageText = TextStyle(
    fontSize: 16.0,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle messageTextBold = TextStyle(
    fontSize: 16.0,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  
  // System message
  static const TextStyle systemText = TextStyle(
    fontSize: 14.0,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: ChatColors.textSecondary,
  );
  
  // Timestamp
  static const TextStyle timestampText = TextStyle(
    fontSize: 12.0,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: ChatColors.textSecondary,
  );
  
  // AppBar
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 18.0,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: ChatColors.textPrimary,
  );
  
  static const TextStyle appBarSubtitle = TextStyle(
    fontSize: 12.0,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: ChatColors.online,
  );
  
  // Quick reply
  static const TextStyle quickReplyText = TextStyle(
    fontSize: 14.0,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  // Input
  static const TextStyle inputText = TextStyle(
    fontSize: 16.0,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: ChatColors.textPrimary,
  );
  
  static const TextStyle inputHint = TextStyle(
    fontSize: 16.0,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: ChatColors.textSecondary,
  );
}

// Instagram-style shadows
class ChatShadows {
  static const BoxShadow soft = BoxShadow(
    color: Color(0x10000000),
    offset: Offset(0, 2),
    blurRadius: 8,
    spreadRadius: 0,
  );
  
  static const BoxShadow medium = BoxShadow(
    color: Color(0x15000000),
    offset: Offset(0, 4),
    blurRadius: 12,
    spreadRadius: 0,
  );
  
  static const BoxShadow strong = BoxShadow(
    color: Color(0x20000000),
    offset: Offset(0, 8),
    blurRadius: 16,
    spreadRadius: 0,
  );
  
  static const List<BoxShadow> card = [soft];
  static const List<BoxShadow> popup = [medium];
  static const List<BoxShadow> modal = [strong];
}