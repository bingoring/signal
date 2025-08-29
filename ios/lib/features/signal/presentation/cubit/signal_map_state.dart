import 'package:equatable/equatable.dart';

import '../../data/models/signal_model.dart';
import 'signal_map_cubit.dart';

class SignalMapState extends Equatable {
  final bool isLoading;
  final List<SignalWithDistance> signals;
  final Signal? selectedSignal;
  final double? userLatitude;
  final double? userLongitude;
  final double searchRadius;
  final List<String> selectedCategories;
  final String? searchQuery;
  final MapBounds? mapBounds;
  final DateTime? lastUpdateTime;
  final String? error;

  const SignalMapState({
    this.isLoading = false,
    this.signals = const [],
    this.selectedSignal,
    this.userLatitude,
    this.userLongitude,
    this.searchRadius = 5000.0, // 기본 5km
    this.selectedCategories = const [],
    this.searchQuery,
    this.mapBounds,
    this.lastUpdateTime,
    this.error,
  });

  /// 필터가 활성화되어 있는지 확인
  bool get hasActiveFilters =>
      selectedCategories.isNotEmpty || 
      searchRadius != 5000.0;

  /// 사용자 위치가 있는지 확인
  bool get hasUserLocation =>
      userLatitude != null && userLongitude != null;

  /// 선택된 시그널이 있는지 확인
  bool get hasSelectedSignal => selectedSignal != null;

  /// 시그널 개수
  int get signalCount => signals.length;

  /// 반경 내 활성 시그널 개수
  int get activeSignalCount =>
      signals.where((s) => s.signal.status == 'active').length;

  SignalMapState copyWith({
    bool? isLoading,
    List<SignalWithDistance>? signals,
    Signal? selectedSignal,
    double? userLatitude,
    double? userLongitude,
    double? searchRadius,
    List<String>? selectedCategories,
    String? searchQuery,
    MapBounds? mapBounds,
    DateTime? lastUpdateTime,
    String? error,
  }) {
    return SignalMapState(
      isLoading: isLoading ?? this.isLoading,
      signals: signals ?? this.signals,
      selectedSignal: selectedSignal,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      searchRadius: searchRadius ?? this.searchRadius,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      searchQuery: searchQuery ?? this.searchQuery,
      mapBounds: mapBounds ?? this.mapBounds,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        signals,
        selectedSignal,
        userLatitude,
        userLongitude,
        searchRadius,
        selectedCategories,
        searchQuery,
        mapBounds,
        lastUpdateTime,
        error,
      ];
}