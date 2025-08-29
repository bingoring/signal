import 'package:flutter/material.dart';
import 'package:signal_app/core/constants/app_constants.dart';

class CategorySelector extends StatefulWidget {
  final String? selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySelector({
    Key? key,
    this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<CategoryItem> _categories = [
    CategoryItem(
      id: 'sports',
      name: '운동',
      icon: Icons.sports_soccer,
      color: const Color(0xFF4CAF50),
      description: '축구, 농구, 테니스, 헬스 등',
    ),
    CategoryItem(
      id: 'food',
      name: '맛집',
      icon: Icons.restaurant,
      color: const Color(0xFFFF9800),
      description: '맛집 탐방, 카페, 디저트 등',
    ),
    CategoryItem(
      id: 'study',
      name: '스터디',
      icon: Icons.school,
      color: const Color(0xFF2196F3),
      description: '어학, 독서, 시험준비 등',
    ),
    CategoryItem(
      id: 'culture',
      name: '문화',
      icon: Icons.palette,
      color: const Color(0xFF9C27B0),
      description: '전시회, 공연, 영화 등',
    ),
    CategoryItem(
      id: 'travel',
      name: '여행',
      icon: Icons.flight_takeoff,
      color: const Color(0xFF00BCD4),
      description: '여행, 드라이브, 나들이 등',
    ),
    CategoryItem(
      id: 'hobby',
      name: '취미',
      icon: Icons.palette,
      color: const Color(0xFFE91E63),
      description: '사진, 요리, 게임 등',
    ),
    CategoryItem(
      id: 'business',
      name: '비즈니스',
      icon: Icons.business_center,
      color: const Color(0xFF607D8B),
      description: '네트워킹, 창업, 투자 등',
    ),
    CategoryItem(
      id: 'other',
      name: '기타',
      icon: Icons.more_horiz,
      color: const Color(0xFF757575),
      description: '기타 활동',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '어떤 활동을 함께 할까요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '관심있는 카테고리를 선택해주세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = widget.selectedCategory == category.id;

                return _buildCategoryCard(category, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryItem category, bool isSelected) {
    return GestureDetector(
      onTap: () => _onCategoryTap(category.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? category.color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? category.color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: category.color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.icon,
                size: 32,
                color: isSelected ? category.color : Colors.grey.shade600,
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? category.color : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                category.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCategoryTap(String categoryId) {
    widget.onCategorySelected(categoryId);
    
    // 햅틱 피드백
    // HapticFeedback.selectionClick();
    
    // 선택 애니메이션
    _animationController.reset();
    _animationController.forward();
  }
}

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}