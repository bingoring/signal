import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/buddy_cubit.dart';
import '../cubit/buddy_state.dart';
import '../widgets/potential_buddy_item.dart';

class PotentialBuddiesPage extends StatefulWidget {
  const PotentialBuddiesPage({super.key});

  @override
  State<PotentialBuddiesPage> createState() => _PotentialBuddiesPageState();
}

class _PotentialBuddiesPageState extends State<PotentialBuddiesPage> {
  int minInteractions = 2;
  double minMannerScore = 4.0;

  @override
  void initState() {
    super.initState();
    _loadPotentialBuddies();
  }

  void _loadPotentialBuddies() {
    context.read<BuddyCubit>().loadPotentialBuddies(
          minInteractions: minInteractions,
          minMannerScore: minMannerScore,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단골 후보자'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: BlocBuilder<BuddyCubit, BuddyState>(
        builder: (context, state) {
          if (state.potentialError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '단골 후보자를 불러올 수 없습니다',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.potentialError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadPotentialBuddies,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (state.potentialBuddies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '조건에 맞는 단골 후보자가 없습니다',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '필터 조건을 조정해보세요',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _showFilterDialog,
                    child: const Text('필터 조정'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadPotentialBuddies(),
            child: Column(
              children: [
                // 필터 요약
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '최소 상호작용 ${minInteractions}회 · 매너 점수 ${minMannerScore.toStringAsFixed(1)} 이상',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _showFilterDialog,
                        child: const Text('변경'),
                      ),
                    ],
                  ),
                ),

                // 후보자 목록
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.potentialBuddies.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final candidate = state.potentialBuddies[index];
                      return PotentialBuddyItem(
                        candidate: candidate,
                        onAddBuddy: () => _addBuddy(candidate),
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필터 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '최소 상호작용 수: $minInteractions회',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: minInteractions.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (value) {
                setState(() {
                  minInteractions = value.round();
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              '최소 매너 점수: ${minMannerScore.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Slider(
              value: minMannerScore,
              min: 0.0,
              max: 10.0,
              divisions: 100,
              onChanged: (value) {
                setState(() {
                  minMannerScore = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadPotentialBuddies();
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  void _addBuddy(PotentialBuddyModel candidate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${candidate.displayedName}님을 단골로 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${candidate.displayedName}님과 단골 관계를 맺으시겠습니까?'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber[600], size: 16),
                const SizedBox(width: 4),
                Text('매너 점수: ${candidate.mannerScore.toStringAsFixed(1)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.handshake, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
                Text('상호작용: ${candidate.interactionCount}회'),
              ],
            ),
            if (candidate.commonCategories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '공통 관심사: ${candidate.commonCategories.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<BuddyCubit>().createBuddy(candidate.userId);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${candidate.displayedName}님을 단골로 추가했습니다'),
                  ),
                );
                _loadPotentialBuddies(); // 목록 새로고침
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('단골 추가에 실패했습니다'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('단골 추가'),
          ),
        ],
      ),
    );
  }
}