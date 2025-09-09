import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/signal.dart';

class EnhancedCategorySelector extends StatefulWidget {
  final String? selectedCategory;
  final Function(String) onCategorySelected;
  final bool allowMultiple;
  final Set<String>? selectedCategories;
  final Function(Set<String>)? onMultipleCategoriesSelected;

  const EnhancedCategorySelector({
    super.key,
    this.selectedCategory,
    required this.onCategorySelected,
    this.allowMultiple = false,
    this.selectedCategories,
    this.onMultipleCategoriesSelected,
  });

  @override
  State<EnhancedCategorySelector> createState() => _EnhancedCategorySelectorState();
}

class _EnhancedCategorySelectorState extends State<EnhancedCategorySelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  Set<String> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeSelection();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  void _initializeSelection() {
    if (widget.allowMultiple && widget.selectedCategories != null) {
      _selectedCategories = Set.from(widget.selectedCategories!);
    } else if (!widget.allowMultiple && widget.selectedCategory != null) {
      _selectedCategories = {widget.selectedCategory!};
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    HapticFeedback.lightImpact();
    
    setState(() {
      if (widget.allowMultiple) {
        if (_selectedCategories.contains(category)) {
          _selectedCategories.remove(category);
        } else {
          _selectedCategories.add(category);
        }
        widget.onMultipleCategoriesSelected?.call(_selectedCategories);
      } else {
        _selectedCategories = {category};
        widget.onCategorySelected(category);
      }
    });
  }

  bool _isCategorySelected(String category) {
    return _selectedCategories.contains(category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.allowMultiple) ...[
              Text(
                '관심사를 선택해주세요 (여러개 선택 가능)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _isCategorySelected(category.id);
                
                return _buildCategoryCard(context, category, isSelected);
              },
            ),
            
            if (_selectedCategories.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSelectedSummary(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CategoryData category, bool isSelected) {
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        elevation: isSelected ? 8 : 2,
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface,
        child: InkWell(
          onTap: () => _selectCategory(category.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(isSelected ? 12 : 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    size: isSelected ? 28 : 24,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Category name
                Text(
                  category.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 4),
                
                // Description
                Text(
                  category.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSummary(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.allowMultiple 
                    ? '선택된 관심사 (${_selectedCategories.length}개)'
                    : '선택된 관심사',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedCategories.map((categoryId) {
              final category = _categories.firstWhere((c) => c.id == categoryId);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.icon,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static const List<CategoryData> _categories = [
    CategoryData(
      id: InterestCategory.sports,
      name: '운동/스포츠',
      description: '축구, 농구, 러닝 등',
      icon: Icons.sports_soccer,
    ),
    CategoryData(
      id: InterestCategory.food,
      name: '맛집/카페',
      description: '맛집 탐방, 카페 투어',
      icon: Icons.restaurant,
    ),
    CategoryData(
      id: InterestCategory.game,
      name: '게임',
      description: '보드게임, PC방 등',
      icon: Icons.sports_esports,
    ),
    CategoryData(
      id: InterestCategory.culture,
      name: '문화/예술',
      description: '전시회, 공연, 미술관',
      icon: Icons.palette,
    ),
    CategoryData(
      id: InterestCategory.study,
      name: '스터디',
      description: '언어, 취업, 시험',
      icon: Icons.school,
    ),
    CategoryData(
      id: InterestCategory.hobby,
      name: '취미',
      description: '독서, 사진, 수공예',
      icon: Icons.interests,
    ),
    CategoryData(
      id: InterestCategory.travel,
      name: '여행',
      description: '국내외 여행, 캠핑',
      icon: Icons.flight,
    ),
    CategoryData(
      id: InterestCategory.shopping,
      name: '쇼핑',
      description: '쇼핑몰, 마켓 투어',
      icon: Icons.shopping_bag,
    ),
    CategoryData(
      id: InterestCategory.music,
      name: '음악',
      description: '콘서트, 페스티벌',
      icon: Icons.music_note,
    ),
    CategoryData(
      id: InterestCategory.movie,
      name: '영화',
      description: '영화관, 영화제',
      icon: Icons.movie,
    ),
  ];
}

class CategoryData {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const CategoryData({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

// Helper functions for category display
extension CategoryExtensions on String {
  String get displayName {
    const categoryMap = {
      InterestCategory.sports: '운동/스포츠',
      InterestCategory.food: '맛집/카페',
      InterestCategory.game: '게임',
      InterestCategory.culture: '문화/예술',
      InterestCategory.study: '스터디',
      InterestCategory.hobby: '취미',
      InterestCategory.travel: '여행',
      InterestCategory.shopping: '쇼핑',
      InterestCategory.music: '음악',
      InterestCategory.movie: '영화',
    };
    return categoryMap[this] ?? this;
  }

  IconData get categoryIcon {
    const iconMap = {
      InterestCategory.sports: Icons.sports_soccer,
      InterestCategory.food: Icons.restaurant,
      InterestCategory.game: Icons.sports_esports,
      InterestCategory.culture: Icons.palette,
      InterestCategory.study: Icons.school,
      InterestCategory.hobby: Icons.interests,
      InterestCategory.travel: Icons.flight,
      InterestCategory.shopping: Icons.shopping_bag,
      InterestCategory.music: Icons.music_note,
      InterestCategory.movie: Icons.movie,
    };
    return iconMap[this] ?? Icons.category;
  }

  Color categoryColor(BuildContext context) {
    final theme = Theme.of(context);
    const colorMap = {
      InterestCategory.sports: Colors.green,
      InterestCategory.food: Colors.orange,
      InterestCategory.game: Colors.purple,
      InterestCategory.culture: Colors.pink,
      InterestCategory.study: Colors.blue,
      InterestCategory.hobby: Colors.teal,
      InterestCategory.travel: Colors.indigo,
      InterestCategory.shopping: Colors.red,
      InterestCategory.music: Colors.deepPurple,
      InterestCategory.movie: Colors.brown,
    };
    return colorMap[this] ?? theme.colorScheme.primary;
  }
}