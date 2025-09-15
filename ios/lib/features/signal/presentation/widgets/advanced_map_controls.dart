import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/enhanced_map_cubit.dart';
import '../cubit/enhanced_map_state.dart';

/// 고급 지도 컨트롤 위젯
class AdvancedMapControls extends StatefulWidget {
  final VoidCallback? onSearchModeChanged;
  final VoidCallback? onVisualizationModeChanged;

  const AdvancedMapControls({
    super.key,
    this.onSearchModeChanged,
    this.onVisualizationModeChanged,
  });

  @override
  State<AdvancedMapControls> createState() => _AdvancedMapControlsState();
}

class _AdvancedMapControlsState extends State<AdvancedMapControls>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _fadeController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _expandController.forward();
      _fadeController.forward();
    } else {
      _expandController.reverse();
      _fadeController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnhancedMapCubit, EnhancedMapState>(
      builder: (context, state) {
        return Positioned(
          top: 100,
          left: 16,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 메인 컨트롤 버튼
                _buildMainControlButton(state),
                
                // 확장된 컨트롤들
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          _buildSearchModeControls(state),
                          const SizedBox(height: 8),
                          _buildVisualizationControls(state),
                          const SizedBox(height: 8),
                          _buildAdvancedFilters(state),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainControlButton(EnhancedMapState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: _toggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.close : Icons.tune,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isExpanded ? '닫기' : '고급 검색',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (state.hasActiveAdvancedFilters) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchModeControls(EnhancedMapState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '검색 모드',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModeChip(
                'radius',
                '반경',
                Icons.radio_button_checked,
                state.searchMode == MapSearchMode.radius,
                () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.radius),
              ),
              _buildModeChip(
                'polygon',
                '다각형',
                Icons.polygon,
                state.searchMode == MapSearchMode.polygon,
                () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.polygon),
              ),
              _buildModeChip(
                'route',
                '경로',
                Icons.route,
                state.searchMode == MapSearchMode.route,
                () => context.read<EnhancedMapCubit>().setSearchMode(MapSearchMode.route),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizationControls(EnhancedMapState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시각화',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModeChip(
                'normal',
                '일반',
                Icons.map,
                state.visualizationMode == MapVisualizationMode.normal,
                () => context.read<EnhancedMapCubit>().setVisualizationMode(MapVisualizationMode.normal),
              ),
              _buildModeChip(
                'density',
                '밀도',
                Icons.scatter_plot,
                state.visualizationMode == MapVisualizationMode.density,
                () => context.read<EnhancedMapCubit>().setVisualizationMode(MapVisualizationMode.density),
              ),
              _buildModeChip(
                'clusters',
                '클러스터',
                Icons.group_work,
                state.visualizationMode == MapVisualizationMode.clusters,
                () => context.read<EnhancedMapCubit>().setVisualizationMode(MapVisualizationMode.clusters),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters(EnhancedMapState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '고급 필터',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (state.hasActiveAdvancedFilters)
                TextButton(
                  onPressed: () => context.read<EnhancedMapCubit>().clearAdvancedFilters(),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '초기화',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 검색 반경 슬라이더
          _buildRangeSlider(
            '검색 반경',
            '${(state.searchRadius / 1000).toStringAsFixed(1)} km',
            state.searchRadius,
            500,
            50000,
            (value) => context.read<EnhancedMapCubit>().updateSearchRadius(value),
          ),
          
          const SizedBox(height: 16),
          
          // 시간 필터
          _buildTimeFilterRow(state),
          
          const SizedBox(height: 16),
          
          // 카테고리 필터
          _buildCategoryFilterRow(state),
        ],
      ),
    );
  }

  Widget _buildModeChip(
    String value,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).primaryColor 
            : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSlider(
    String label,
    String value,
    double currentValue,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: currentValue,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeFilterRow(EnhancedMapState state) {
    final timeSlots = ['전체', '오전', '오후', '저녁', '밤'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시간대',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: timeSlots.map((slot) {
            final isSelected = state.selectedTimeSlots.contains(slot) || 
                              (slot == '전체' && state.selectedTimeSlots.isEmpty);
            
            return GestureDetector(
              onTap: () => context.read<EnhancedMapCubit>().toggleTimeSlot(slot),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterRow(EnhancedMapState state) {
    final categories = ['전체', '운동', '맛집', '문화', '여행', '쇼핑', '기타'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '카테고리',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: categories.map((category) {
            final isSelected = state.selectedCategories.contains(category) || 
                              (category == '전체' && state.selectedCategories.isEmpty);
            
            return GestureDetector(
              onTap: () => context.read<EnhancedMapCubit>().toggleCategory(category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}