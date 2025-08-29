import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/signal_map_cubit.dart';
import '../cubit/signal_map_state.dart';

class SignalFilterSheet extends StatefulWidget {
  const SignalFilterSheet({super.key});

  @override
  State<SignalFilterSheet> createState() => _SignalFilterSheetState();
}

class _SignalFilterSheetState extends State<SignalFilterSheet> {
  late double _selectedRadius;
  late Set<String> _selectedCategories;

  final List<FilterCategory> _categories = [
    FilterCategory('sports', '스포츠', Icons.sports_soccer, Colors.orange),
    FilterCategory('food', '맛집', Icons.restaurant, Colors.red),
    FilterCategory('culture', '문화', Icons.theater_comedy, Colors.purple),
    FilterCategory('study', '스터디', Icons.menu_book, Colors.blue),
    FilterCategory('hobby', '취미', Icons.palette, Colors.green),
    FilterCategory('travel', '여행', Icons.flight, Colors.teal),
    FilterCategory('shopping', '쇼핑', Icons.shopping_bag, Colors.pink),
    FilterCategory('entertainment', '엔터테인먼트', Icons.movie, Colors.indigo),
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<SignalMapCubit>().state;
    _selectedRadius = state.searchRadius;
    _selectedCategories = Set.from(state.selectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  '필터 설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const Spacer(),
                
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('초기화'),
                ),
              ],
            ),
          ),

          const Divider(),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 검색 반경 설정
                  _buildRadiusSection(),
                  
                  const SizedBox(height: 24),
                  
                  // 카테고리 필터
                  _buildCategorySection(),
                  
                  const SizedBox(height: 32),
                  
                  // 적용 버튼
                  _buildApplyButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '검색 반경',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '반경',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    _formatRadius(_selectedRadius),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: _selectedRadius,
                  min: 500,
                  max: 50000,
                  divisions: 19, // 500m, 1km, 2km, ..., 50km
                  onChanged: (value) {
                    setState(() {
                      _selectedRadius = value;
                    });
                  },
                ),
              ),
              
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('500m', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('50km', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 빠른 선택 버튼들
        Row(
          children: [
            _buildQuickRadiusButton('1km', 1000),
            const SizedBox(width: 8),
            _buildQuickRadiusButton('3km', 3000),
            const SizedBox(width: 8),
            _buildQuickRadiusButton('5km', 5000),
            const SizedBox(width: 8),
            _buildQuickRadiusButton('10km', 10000),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickRadiusButton(String label, double radius) {
    final isSelected = _selectedRadius == radius;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRadius = radius;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '관심 카테고리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const Spacer(),
            
            Text(
              '${_selectedCategories.length}개 선택',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategories.contains(category.value);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(category.value);
                  } else {
                    _selectedCategories.add(category.value);
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected 
                    ? category.color.withOpacity(0.1)
                    : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                      ? category.color
                      : Colors.grey[200]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category.icon,
                      size: 18,
                      color: isSelected ? category.color : Colors.grey[600],
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? category.color : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _applyFilters,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '필터 적용',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatRadius(double radius) {
    if (radius < 1000) {
      return '${radius.round()}m';
    } else {
      final km = radius / 1000;
      if (km % 1 == 0) {
        return '${km.round()}km';
      } else {
        return '${km.toStringAsFixed(1)}km';
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedRadius = 5000;
      _selectedCategories.clear();
    });
  }

  void _applyFilters() {
    final cubit = context.read<SignalMapCubit>();
    
    // 반경 업데이트
    cubit.updateSearchRadius(_selectedRadius);
    
    // 카테고리 필터 업데이트
    cubit.updateCategoryFilter(_selectedCategories.toList());
    
    Navigator.pop(context);
  }
}

class FilterCategory {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const FilterCategory(this.value, this.label, this.icon, this.color);
}