import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/avatar_service.dart';
import '../widgets/avatar_category_grid.dart';
import '../widgets/avatar_search_bar.dart';
import '../widgets/personality_preview.dart';
import '../widgets/favorites_section.dart';
import '../widgets/recent_section.dart';

/// Phase 2: 이모지 아바타 선택 페이지
/// 카테고리별 아바타, 검색, 즐겨찾기, 최근 사용 기능 포함
class AvatarSelectionPage extends StatefulWidget {
  final String? currentAvatar;
  final Function(String emoji) onAvatarSelected;
  final bool showPersonalityPreview;

  const AvatarSelectionPage({
    super.key,
    this.currentAvatar,
    required this.onAvatarSelected,
    this.showPersonalityPreview = true,
  });

  @override
  State<AvatarSelectionPage> createState() => _AvatarSelectionPageState();
}

class _AvatarSelectionPageState extends State<AvatarSelectionPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  AvatarSelectionResponse? _avatarData;
  List<Avatar> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String _searchQuery = '';
  
  // 선택된 카테고리 인덱스
  int _selectedCategoryIndex = 0;
  String? _tempSelectedAvatar;

  @override
  void initState() {
    super.initState();
    _tempSelectedAvatar = widget.currentAvatar;
    _loadAvatarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 맞춤 아바타 데이터 로드
      final response = await AvatarService(Dio()).getUserAvatarSelection();
      final data = response.data;
      
      setState(() {
        _avatarData = data;
        _isLoading = false;
      });

      // TabController 초기화 (카테고리 수 + 즐겨찾기/최근 탭)
      int totalTabs = data.categories.length;
      if (data.favorites?.isNotEmpty == true) totalTabs++;
      if (data.recent?.isNotEmpty == true) totalTabs++;
      
      _tabController = TabController(length: totalTabs, vsync: this);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아바타 데이터를 불러올 수 없습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchAvatars(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final response = await AvatarService(Dio()).searchAvatars(query, null, 20);
      setState(() {
        _searchResults = response.data.results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _selectAvatar(String emoji) {
    setState(() {
      _tempSelectedAvatar = emoji;
    });
  }

  void _confirmSelection() {
    if (_tempSelectedAvatar != null) {
      widget.onAvatarSelected(_tempSelectedAvatar!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '아바타 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
        actions: [
          if (_tempSelectedAvatar != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 검색 바
                _buildSearchSection(),
                
                // 현재 선택된 아바타 미리보기
                if (_tempSelectedAvatar != null) _buildSelectedAvatarPreview(),
                
                // 메인 콘텐츠
                Expanded(
                  child: _searchQuery.isNotEmpty
                      ? _buildSearchResults()
                      : _buildCategorizedAvatars(),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          AvatarSearchBar(
            controller: _searchController,
            onSearch: _searchAvatars,
            isLoading: _isSearching,
          ),
          
          // 개성 분석 미리보기 (검색 중이 아닐 때만 표시)
          if (widget.showPersonalityPreview && _searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PersonalityPreview(
                currentAvatar: _tempSelectedAvatar ?? widget.currentAvatar,
                onAnalysisRequested: _showPersonalityAnalysis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedAvatarPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                _tempSelectedAvatar!,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '선택된 아바타',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getAvatarName(_tempSelectedAvatar!) ?? '이모지 아바타',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: Colors.blue,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('검색 중...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "'$_searchQuery'에 대한 결과가 없습니다",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 키워드로 검색해보세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "'$_searchQuery' 검색 결과 (${_searchResults.length}개)",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final avatar = _searchResults[index];
                final isSelected = _tempSelectedAvatar == avatar.emoji;
                
                return _buildAvatarItem(
                  avatar.emoji,
                  avatar.name,
                  isSelected,
                  () => _selectAvatar(avatar.emoji),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedAvatars() {
    if (_avatarData == null) {
      return const Center(child: Text('데이터를 불러올 수 없습니다'));
    }

    final data = _avatarData!;
    
    return DefaultTabController(
      length: _tabController.length,
      child: Column(
        children: [
          // 탭 바
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                // 즐겨찾기 탭
                if (data.favorites?.isNotEmpty == true)
                  const Tab(
                    icon: Icon(Icons.favorite, size: 20),
                    text: '즐겨찾기',
                  ),
                
                // 최근 사용 탭
                if (data.recent?.isNotEmpty == true)
                  const Tab(
                    icon: Icon(Icons.history, size: 20),
                    text: '최근 사용',
                  ),
                
                // 카테고리 탭들
                ...data.categories.map((category) => Tab(
                  text: category.displayName,
                )).toList(),
              ],
            ),
          ),
          
          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 즐겨찾기 탭 내용
                if (data.favorites?.isNotEmpty == true)
                  FavoritesSection(
                    favorites: data.favorites!,
                    selectedAvatar: _tempSelectedAvatar,
                    onAvatarSelected: _selectAvatar,
                  ),
                
                // 최근 사용 탭 내용
                if (data.recent?.isNotEmpty == true)
                  RecentSection(
                    recent: data.recent!,
                    selectedAvatar: _tempSelectedAvatar,
                    onAvatarSelected: _selectAvatar,
                  ),
                
                // 카테고리 탭 내용들
                ...data.categories.map((category) => 
                  AvatarCategoryGrid(
                    category: category,
                    selectedAvatar: _tempSelectedAvatar,
                    onAvatarSelected: _selectAvatar,
                  ),
                ).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarItem(
    String emoji,
    String name,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String? _getAvatarName(String emoji) {
    if (_avatarData == null) return null;
    
    for (final category in _avatarData!.categories) {
      for (final avatar in category.avatars) {
        if (avatar.emoji == emoji) {
          return avatar.name;
        }
      }
    }
    return null;
  }

  void _showPersonalityAnalysis() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '나의 아바타 성향 분석',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: FutureBuilder<AvatarPersonality>(
                    future: _getPersonalityAnalysis(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('분석 중 오류가 발생했습니다: ${snapshot.error}'),
                        );
                      }
                      
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Text('아직 분석할 데이터가 부족합니다'),
                        );
                      }
                      
                      return _buildPersonalityAnalysisContent(
                        snapshot.data!,
                        scrollController,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<AvatarPersonality> _getPersonalityAnalysis() async {
    final response = await AvatarService(Dio()).getPersonalityAnalysis();
    return response.data;
  }

  Widget _buildPersonalityAnalysisContent(
    AvatarPersonality personality,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 성향 타입
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  personality.type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  personality.description,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 성향 특성들
          if (personality.traits.isNotEmpty) ...[
            const Text(
              '성향 특성',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...personality.traits.map((trait) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trait.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${trait.score.toInt()}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: trait.score / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trait.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
          
          const SizedBox(height: 24),
          
          // 추천 아바타들
          if (personality.suggestions.isNotEmpty) ...[
            const Text(
              '추천 아바타',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: personality.suggestions.length,
                itemBuilder: (context, index) {
                  final avatar = personality.suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        _selectAvatar(avatar.emoji);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Text(
                            avatar.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}