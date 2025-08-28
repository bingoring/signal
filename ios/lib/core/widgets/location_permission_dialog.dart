import 'package:flutter/material.dart';
import '../services/location_service.dart';

class LocationPermissionDialog extends StatelessWidget {
  final LocationPermissionResult permissionResult;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onRetryPressed;

  const LocationPermissionDialog({
    super.key,
    required this.permissionResult,
    this.onSettingsPressed,
    this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          const Text('위치 권한 필요'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getDescription(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '위치 정보는 근처 시그널을 찾기 위해서만 사용되며, 서버에 저장되지 않습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('나중에'),
        ),
        if (permissionResult == LocationPermissionResult.permanentlyDenied ||
            permissionResult == LocationPermissionResult.serviceDisabled) ...[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSettingsPressed?.call();
            },
            child: const Text('설정 열기'),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetryPressed?.call();
            },
            child: const Text('다시 시도'),
          ),
        ],
      ],
    );
  }

  String _getDescription() {
    switch (permissionResult) {
      case LocationPermissionResult.denied:
        return '주변의 시그널을 찾기 위해 위치 권한이 필요합니다. 권한을 허용해 주세요.';
      case LocationPermissionResult.permanentlyDenied:
        return '위치 권한이 거부되었습니다. 앱 설정에서 위치 권한을 허용해 주세요.';
      case LocationPermissionResult.serviceDisabled:
        return '기기의 위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화해 주세요.';
      case LocationPermissionResult.error:
        return '위치 권한을 확인하는 중 오류가 발생했습니다. 다시 시도해 주세요.';
      default:
        return '위치 서비스를 사용할 수 없습니다.';
    }
  }

  /// 정적 메서드로 다이얼로그 표시
  static Future<void> show(
    BuildContext context,
    LocationPermissionResult result, {
    VoidCallback? onSettingsPressed,
    VoidCallback? onRetryPressed,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LocationPermissionDialog(
        permissionResult: result,
        onSettingsPressed: onSettingsPressed,
        onRetryPressed: onRetryPressed,
      ),
    );
  }
}

/// 위치 권한 상태를 보여주는 BottomSheet
class LocationPermissionBottomSheet extends StatefulWidget {
  final LocationPermissionResult permissionResult;

  const LocationPermissionBottomSheet({
    super.key,
    required this.permissionResult,
  });

  @override
  State<LocationPermissionBottomSheet> createState() =>
      _LocationPermissionBottomSheetState();
}

class _LocationPermissionBottomSheetState
    extends State<LocationPermissionBottomSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 아이콘
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              size: 40,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          const Text(
            '위치 권한이 필요해요',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 설명
          Text(
            _getDetailedDescription(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 버튼들
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleMainAction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _getMainActionText(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('나중에 하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDetailedDescription() {
    switch (widget.permissionResult) {
      case LocationPermissionResult.denied:
        return '주변의 시그널을 찾고 정확한 거리 정보를 제공하기 위해 위치 권한이 필요합니다.';
      case LocationPermissionResult.permanentlyDenied:
        return '위치 권한이 거부된 상태입니다. 앱 설정에서 위치 권한을 허용해 주세요.';
      case LocationPermissionResult.serviceDisabled:
        return '기기의 위치 서비스가 꺼져있습니다. 설정에서 위치 서비스를 활성화해 주세요.';
      default:
        return '위치 서비스 사용에 문제가 발생했습니다.';
    }
  }

  String _getMainActionText() {
    switch (widget.permissionResult) {
      case LocationPermissionResult.permanentlyDenied:
      case LocationPermissionResult.serviceDisabled:
        return '설정 열기';
      default:
        return '권한 허용하기';
    }
  }

  Future<void> _handleMainAction() async {
    setState(() => _isLoading = true);

    try {
      bool success = false;
      
      if (widget.permissionResult == LocationPermissionResult.permanentlyDenied) {
        success = await LocationService().openAppSettings();
      } else if (widget.permissionResult == LocationPermissionResult.serviceDisabled) {
        success = await LocationService().openLocationSettings();
      } else {
        final result = await LocationService().requestPermission();
        success = result == LocationPermissionResult.granted;
      }

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 정적 메서드로 BottomSheet 표시
  static Future<bool?> show(
    BuildContext context,
    LocationPermissionResult result,
  ) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPermissionBottomSheet(
        permissionResult: result,
      ),
    );
  }
}