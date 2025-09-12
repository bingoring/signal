import 'package:flutter/material.dart';

/// 매너온도 기반 신뢰도 레벨을 시각적으로 표시하는 위젯
class TrustLevelIndicator extends StatelessWidget {
  final double mannerTemperature;
  final TrustIndicatorSize size;
  final bool showLabel;
  final bool showTemperature;

  const TrustLevelIndicator({
    super.key,
    required this.mannerTemperature,
    this.size = TrustIndicatorSize.medium,
    this.showLabel = true,
    this.showTemperature = false,
  });

  @override
  Widget build(BuildContext context) {
    final trustLevel = _getTrustLevel(mannerTemperature);
    final color = _getTemperatureColor(mannerTemperature);
    final dimensions = _getDimensions();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Temperature thermometer icon
        Container(
          width: dimensions.iconSize,
          height: dimensions.iconSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(dimensions.iconSize / 2),
          ),
          child: Icon(
            Icons.thermostat,
            color: Colors.white,
            size: dimensions.iconSize * 0.6,
          ),
        ),
        
        if (showTemperature || showLabel) const SizedBox(width: 8),
        
        // Temperature text
        if (showTemperature)
          Text(
            '${mannerTemperature.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: dimensions.fontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
            
        if (showTemperature && showLabel) const SizedBox(width: 4),
        
        // Trust level label
        if (showLabel)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: dimensions.paddingHorizontal,
              vertical: dimensions.paddingVertical,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(dimensions.borderRadius),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              trustLevel,
              style: TextStyle(
                fontSize: dimensions.labelFontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
      ],
    );
  }

  String _getTrustLevel(double temp) {
    if (temp >= 45.0) return '매우 높음';
    if (temp >= 40.0) return '높음';
    if (temp >= 35.0) return '보통';
    if (temp >= 30.0) return '낮음';
    return '매우 낮음';
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return const Color(0xFF4CAF50); // 매우 높음 - 초록
    if (temp >= 40.0) return const Color(0xFF2196F3); // 높음 - 파랑
    if (temp >= 35.0) return const Color(0xFFFF9800); // 보통 - 주황
    if (temp >= 30.0) return const Color(0xFFF44336); // 낮음 - 빨강
    return const Color(0xFF9E9E9E); // 매우 낮음 - 회색
  }

  _TrustIndicatorDimensions _getDimensions() {
    switch (size) {
      case TrustIndicatorSize.small:
        return const _TrustIndicatorDimensions(
          iconSize: 20,
          fontSize: 12,
          labelFontSize: 10,
          paddingHorizontal: 6,
          paddingVertical: 2,
          borderRadius: 8,
        );
      case TrustIndicatorSize.medium:
        return const _TrustIndicatorDimensions(
          iconSize: 24,
          fontSize: 14,
          labelFontSize: 12,
          paddingHorizontal: 8,
          paddingVertical: 4,
          borderRadius: 10,
        );
      case TrustIndicatorSize.large:
        return const _TrustIndicatorDimensions(
          iconSize: 32,
          fontSize: 16,
          labelFontSize: 14,
          paddingHorizontal: 12,
          paddingVertical: 6,
          borderRadius: 12,
        );
    }
  }
}

enum TrustIndicatorSize { small, medium, large }

class _TrustIndicatorDimensions {
  final double iconSize;
  final double fontSize;
  final double labelFontSize;
  final double paddingHorizontal;
  final double paddingVertical;
  final double borderRadius;

  const _TrustIndicatorDimensions({
    required this.iconSize,
    required this.fontSize,
    required this.labelFontSize,
    required this.paddingHorizontal,
    required this.paddingVertical,
    required this.borderRadius,
  });
}

/// 매너온도 진행 바 위젯
class MannerTemperatureProgressBar extends StatelessWidget {
  final double mannerTemperature;
  final double maxTemperature;
  final double minTemperature;
  final double height;
  final bool showLabels;

  const MannerTemperatureProgressBar({
    super.key,
    required this.mannerTemperature,
    this.maxTemperature = 50.0,
    this.minTemperature = 20.0,
    this.height = 8.0,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (mannerTemperature - minTemperature) / (maxTemperature - minTemperature);
    final clampedProgress = progress.clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minTemperature.toInt()}°C',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '${mannerTemperature.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getTemperatureColor(mannerTemperature),
                ),
              ),
              Text(
                '${maxTemperature.toInt()}°C',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.grey[200],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedProgress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: LinearGradient(
                  colors: [
                    _getTemperatureColor(mannerTemperature).withOpacity(0.7),
                    _getTemperatureColor(mannerTemperature),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return const Color(0xFF4CAF50);
    if (temp >= 40.0) return const Color(0xFF2196F3);
    if (temp >= 35.0) return const Color(0xFFFF9800);
    if (temp >= 30.0) return const Color(0xFFF44336);
    return const Color(0xFF9E9E9E);
  }
}

/// 간단한 매너온도 배지
class MannerTemperatureBadge extends StatelessWidget {
  final double mannerTemperature;
  final bool compact;

  const MannerTemperatureBadge({
    super.key,
    required this.mannerTemperature,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getTemperatureColor(mannerTemperature);
    
    return Container(
      padding: compact 
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${mannerTemperature.toStringAsFixed(1)}°C',
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 45.0) return const Color(0xFF4CAF50);
    if (temp >= 40.0) return const Color(0xFF2196F3);
    if (temp >= 35.0) return const Color(0xFFFF9800);
    if (temp >= 30.0) return const Color(0xFFF44336);
    return const Color(0xFF9E9E9E);
  }
}