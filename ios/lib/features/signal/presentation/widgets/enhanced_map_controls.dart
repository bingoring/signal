import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/enhanced_map_cubit.dart';
import '../cubit/enhanced_map_state.dart';

/// 향상된 지도 컨트롤 패널
class EnhancedMapControls extends StatefulWidget {
  const EnhancedMapControls({super.key});

  @override
  State<EnhancedMapControls> createState() => _EnhancedMapControlsState();
}

class _EnhancedMapControlsState extends State<EnhancedMapControls>
    with TickerProviderStateMixin {
  late AnimationController _panelController;
  late AnimationController _modeController;
  bool _isPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _modeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _panelController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
      builder: (context, state) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Column(
            children: [
              // 메인 검색바
              _buildMainSearchBar(context, state),
              
              const SizedBox(height: 12),
              
              // 컨트롤 패널
              _buildControlPanel(context, state),
              
              // 모드 선택 버튼들
              if (_isPanelExpanded) ...[
                const SizedBox(height: 12),
                _buildModeSelector(context, state),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainSearchBar(BuildContext context, EnhancedMapState state) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 검색 입력 필드
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '위치나 시그널 검색...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (query) {
                context.read<EnhancedMapCubit>().searchSignals(query);
              },
            ),
          ),
          
          // 음성 검색 버튼
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.grey),
            onPressed: () {
              // 음성 검색 구현
            },
          ),
          
          // 확장 패널 토글
          IconButton(
            icon: AnimatedRotation(
              turns: _isPanelExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more, color: Colors.grey),
            ),
            onPressed: _togglePanel,
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, EnhancedMapState state) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isPanelExpanded ? 120 : 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 기본 컨트롤 행
            Row(
              children: [
                // 필터 버튼
                _buildControlButton(
                  icon: Icons.filter_alt,
                  label: '필터',
                  isActive: state.hasActiveAdvancedFilters,
                  onTap: () => _showFilterBottomSheet(context),
                ),
                
                const SizedBox(width: 12),
                
                // 밀도 모드 토글
                _buildControlButton(
                  icon: Icons.heatmap,
                  label: '밀도',
                  isActive: state.viewMode == MapViewMode.density,
                  onTap: () => _toggleDensityMode(context),
                ),
                
                const SizedBox(width: 12),
                
                // 클러스터 모드 토글
                _buildControlButton(
                  icon: Icons.group_work,
                  label: '클러스터',
                  isActive: state.viewMode == MapViewMode.cluster,
                  onTap: () => _toggleClusterMode(context),
                ),
                
                const Spacer(),
                
                // 통계 버튼
                _buildControlButton(
                  icon: Icons.analytics,
                  label: '통계',
                  onTap: () => _showStatistics(context),
                ),
              ],
            ),
            
            // 확장된 컨트롤들
            if (_isPanelExpanded) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // 반경 슬라이더
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '검색 반경: ${(state.searchRadius / 1000).toStringAsFixed(1)}km',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: state.searchRadius,
                            min: 500,
                            max: 20000,
                            divisions: 39,
                            onChanged: (value) {
                              context.read<EnhancedMapCubit>().updateSearchRadius(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, EnhancedMapState state) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeButton(
            icon: Icons.location_on,
            label: '반경',
            isSelected: state.searchMode == MapSearchMode.radius,
            onTap: () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.radius),
          ),
          _buildModeButton(
            icon: Icons.crop_free,
            label: '다각형',
            isSelected: state.searchMode == MapSearchMode.polygon,
            onTap: () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.polygon),
          ),
          _buildModeButton(
            icon: Icons.route,
            label: '경로',
            isSelected: state.searchMode == MapSearchMode.route,
            onTap: () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.route),
          ),
          _buildModeButton(
            icon: Icons.explore,
            label: 'POI',
            isSelected: state.searchMode == MapSearchMode.poi,
            onTap: () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.poi),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePanel() {
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
    });
    
    if (_isPanelExpanded) {
      _panelController.forward();
    } else {
      _panelController.reverse();
    }
  }

  void _toggleDensityMode(BuildContext context) {
    final cubit = context.read<EnhancedMapCubit>();
    if (cubit.state.viewMode == MapViewMode.density) {
      cubit.setViewMode(MapViewMode.normal);
    } else {
      cubit.setViewMode(MapViewMode.density);
    }
  }

  void _toggleClusterMode(BuildContext context) {
    final cubit = context.read<EnhancedMapCubit>();
    if (cubit.state.viewMode == MapViewMode.cluster) {
      cubit.setViewMode(MapViewMode.normal);
    } else {
      cubit.setViewMode(MapViewMode.cluster);
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EnhancedFilterBottomSheet(),
    );
  }

  void _showStatistics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StatisticsBottomSheet(),
    );
  }
}

/// 향상된 필터 바텀시트
class EnhancedFilterBottomSheet extends StatefulWidget {
  const EnhancedFilterBottomSheet({super.key});

  @override
  State<EnhancedFilterBottomSheet> createState() => _EnhancedFilterBottomSheetState();
}

class _EnhancedFilterBottomSheetState extends State<EnhancedFilterBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '고급 필터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // 필터 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리 필터
                  _buildCategoryFilter(),
                  
                  const SizedBox(height: 24),
                  
                  // 시간 필터
                  _buildTimeFilter(),
                  
                  const SizedBox(height: 24),
                  
                  // 거리 필터
                  _buildDistanceFilter(),
                  
                  const SizedBox(height: 24),
                  
                  // 참여자 수 필터
                  _buildParticipantFilter(),
                  
                  const SizedBox(height: 24),
                  
                  // 연령대 필터
                  _buildAgeFilter(),
                ],
              ),
            ),
          ),
          
          // 액션 버튼들
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // 필터 초기화
                      context.read<EnhancedMapCubit>().clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // 필터 적용
                      context.read<EnhancedMapCubit>().applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InterestCategory.values.map((category) {
            return BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
              builder: (context, state) {
                final isSelected = state.selectedCategories.contains(category);
                return FilterChip(
                  label: Text(_getCategoryLabel(category)),
                  selected: isSelected,
                  onSelected: (selected) {
                    context.read<EnhancedMapCubit>().toggleCategoryFilter(category);
                  },
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시간대',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
          builder: (context, state) {
            return Column(
              children: [
                SwitchListTile(
                  title: const Text('오늘만'),
                  value: state.todayOnly,
                  onChanged: (value) {
                    context.read<EnhancedMapCubit>().toggleTodayOnly();
                  },
                ),
                if (!state.todayOnly) ...[
                  ListTile(
                    title: const Text('시작 시간'),
                    subtitle: Text(
                      state.startTime?.toString() ?? '설정 안 함',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        context.read<EnhancedMapCubit>().setStartTime(time);
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('종료 시간'),
                    subtitle: Text(
                      state.endTime?.toString() ?? '설정 안 함',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        context.read<EnhancedMapCubit>().setEndTime(time);
                      }
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDistanceFilter() {
    return BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '거리 범위',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(state.minDistance / 1000).toStringAsFixed(1)}km - ${(state.maxDistance / 1000).toStringAsFixed(1)}km',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            RangeSlider(
              values: RangeValues(state.minDistance, state.maxDistance),
              min: 0,
              max: 20000,
              divisions: 40,
              labels: RangeLabels(
                '${(state.minDistance / 1000).toStringAsFixed(1)}km',
                '${(state.maxDistance / 1000).toStringAsFixed(1)}km',
              ),
              onChanged: (values) {
                context.read<EnhancedMapCubit>().setDistanceRange(
                  values.start,
                  values.end,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticipantFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '참여자 수',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('여유있음'),
              selected: false,
              onSelected: (selected) {},
            ),
            FilterChip(
              label: const Text('거의 찬'),
              selected: false,
              onSelected: (selected) {},
            ),
            FilterChip(
              label: const Text('즉시 참여 가능'),
              selected: false,
              onSelected: (selected) {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgeFilter() {
    return BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '연령대',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${state.minAge}세 - ${state.maxAge}세',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            RangeSlider(
              values: RangeValues(state.minAge.toDouble(), state.maxAge.toDouble()),
              min: 18,
              max: 65,
              divisions: 47,
              labels: RangeLabels('${state.minAge}세', '${state.maxAge}세'),
              onChanged: (values) {
                context.read<EnhancedMapCubit>().setAgeRange(
                  values.start.round(),
                  values.end.round(),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'sports':
        return '스포츠';
      case 'food':
        return '음식';
      case 'game':
        return '게임';
      case 'culture':
        return '문화';
      case 'study':
        return '스터디';
      case 'hobby':
        return '취미';
      case 'travel':
        return '여행';
      case 'shopping':
        return '쇼핑';
      case 'music':
        return '음악';
      case 'movie':
        return '영화';
      default:
        return category;
    }
  }
}

/// 통계 바텀시트
class StatisticsBottomSheet extends StatelessWidget {
  const StatisticsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '지역 통계',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // 통계 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (state.statistics != null) ...[
                        _buildStatCard(
                          '총 시그널 수',
                          '${state.statistics!.totalSignals}개',
                          Icons.signal_cellular_alt,
                        ),
                        const SizedBox(height: 16),
                        _buildStatCard(
                          '평균 거리',
                          '${(state.statistics!.averageDistance / 1000).toStringAsFixed(1)}km',
                          Icons.straighten,
                        ),
                        const SizedBox(height: 16),
                        _buildCategoryChart(state.statistics!.categories),
                      ] else
                        const Center(
                          child: Text('통계 데이터를 불러오는 중...'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, int> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '카테고리별 분포',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categories.entries.map((entry) {
              final total = categories.values.fold(0, (sum, count) => sum + count);
              final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(entry.key),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${percentage.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}


// 카테고리 상수
class InterestCategory {
  static const List<String> values = [
    'sports',
    'food',
    'game',
    'culture',
    'study',
    'hobby',
    'travel',
    'shopping',
    'music',
    'movie',
  ];
}