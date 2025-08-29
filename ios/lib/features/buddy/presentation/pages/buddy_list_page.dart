import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/buddy_cubit.dart';
import '../cubit/buddy_state.dart';
import '../widgets/buddy_list_item.dart';
import '../widgets/buddy_search_filter.dart';
import '../widgets/buddy_stats_card.dart';

class BuddyListPage extends StatefulWidget {
  const BuddyListPage({super.key});

  @override
  State<BuddyListPage> createState() => _BuddyListPageState();
}

class _BuddyListPageState extends State<BuddyListPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    
    // 초기 데이터 로드
    context.read<BuddyCubit>().loadBuddies();
    context.read<BuddyCubit>().loadBuddyStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      context.read<BuddyCubit>().loadMoreBuddies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 단골'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchFilter(),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('단골 후보자 보기'),
                onTap: () => Navigator.pushNamed(context, '/potential-buddies'),
              ),
              PopupMenuItem(
                child: const Text('매너 점수 이력'),
                onTap: () => Navigator.pushNamed(context, '/manner-logs'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '활성'),
            Tab(text: '통계'),
          ],
        ),
      ),
      body: BlocBuilder<BuddyCubit, BuddyState>(
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildBuddyList(state, null),
              _buildBuddyList(state, 'active'),
              _buildStatsTab(state),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/potential-buddies'),
        child: const Icon(Icons.person_add),
        tooltip: '새 단골 추가',
      ),
    );
  }

  Widget _buildBuddyList(BuddyState state, String? statusFilter) {
    if (state.isLoading && state.buddies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.buddies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '단골 목록을 불러올 수 없습니다',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<BuddyCubit>().loadBuddies(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final filteredBuddies = statusFilter == null
        ? state.buddies
        : state.buddies.where((buddy) => buddy.status == statusFilter).toList();

    if (filteredBuddies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              statusFilter == null ? '아직 단골이 없습니다' : '활성 단골이 없습니다',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '시그널에 참여해서 새로운 단골을 만나보세요!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<BuddyCubit>().refreshBuddies(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredBuddies.length + (state.hasMoreBuddies ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= filteredBuddies.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final buddy = filteredBuddies[index];
          return BuddyListItem(
            buddy: buddy,
            onTap: () => Navigator.pushNamed(
              context,
              '/buddy-detail',
              arguments: buddy,
            ),
            onMessage: () => _sendMessage(buddy),
            onInvite: () => _inviteToBuddy(buddy),
          );
        },
      ),
    );
  }

  Widget _buildStatsTab(BuddyState state) {
    if (state.isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.statsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '통계를 불러올 수 없습니다',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.statsError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<BuddyCubit>().loadBuddyStats(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.stats == null) {
      return const Center(child: Text('통계 데이터가 없습니다'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BuddyStatsCard(stats: state.stats!),
    );
  }

  void _showSearchFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => BuddySearchFilter(
        onFilter: (filters) {
          context.read<BuddyCubit>().filterBuddies(filters);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _sendMessage(BuddyModel buddy) {
    // 채팅 기능으로 이동
    Navigator.pushNamed(
      context,
      '/chat-room',
      arguments: {
        'userId': buddy.buddyId,
        'userName': buddy.displayName,
      },
    );
  }

  void _inviteToBuddy(BuddyModel buddy) {
    // 단골 초대 기능
    Navigator.pushNamed(
      context,
      '/create-invitation',
      arguments: buddy,
    );
  }
}