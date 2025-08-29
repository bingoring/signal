import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/buddy_cubit.dart';

class MannerEvaluationPage extends StatefulWidget {
  final int rateeId;
  final String rateeName;
  final int? signalId;
  final String? signalTitle;

  const MannerEvaluationPage({
    super.key,
    required this.rateeId,
    required this.rateeName,
    this.signalId,
    this.signalTitle,
  });

  @override
  State<MannerEvaluationPage> createState() => _MannerEvaluationPageState();
}

class _MannerEvaluationPageState extends State<MannerEvaluationPage> {
  String selectedCategory = 'punctuality';
  double scoreChange = 0.0;
  final TextEditingController _reasonController = TextEditingController();

  final List<Map<String, dynamic>> categories = [
    {
      'value': 'punctuality',
      'name': '시간 약속',
      'icon': Icons.access_time,
      'description': '약속 시간을 잘 지켰나요?',
    },
    {
      'value': 'communication',
      'name': '소통',
      'icon': Icons.chat_bubble_outline,
      'description': '원활하게 소통했나요?',
    },
    {
      'value': 'kindness',
      'name': '친절함',
      'icon': Icons.favorite_outline,
      'description': '친절하고 배려심이 있었나요?',
    },
    {
      'value': 'participation',
      'name': '참여도',
      'icon': Icons.groups,
      'description': '적극적으로 참여했나요?',
    },
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.rateeName}님 매너 평가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 시그널 정보 (있는 경우)
            if (widget.signalTitle != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.campaign,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시그널',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              widget.signalTitle!,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 평가 대상자 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.primaryColor,
                      child: Text(
                        widget.rateeName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '평가 대상',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            widget.rateeName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 평가 카테고리 선택
            Text(
              '평가 항목',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...categories.map((category) {
              final isSelected = selectedCategory == category['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = category['value'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withOpacity(0.1)
                        : Colors.grey[50],
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category['icon'],
                        color: isSelected
                            ? theme.primaryColor
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category['name'],
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? theme.primaryColor
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              category['description'],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.primaryColor,
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // 점수 변경
            Text(
              '점수 변경: ${scoreChange > 0 ? '+' : ''}${scoreChange.toStringAsFixed(1)}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scoreChange > 0 ? Colors.green : scoreChange < 0 ? Colors.red : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '매너 점수에 반영될 점수를 선택하세요 (-5.0 ~ +5.0)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // 점수 슬라이더
            Slider(
              value: scoreChange,
              min: -5.0,
              max: 5.0,
              divisions: 100,
              onChanged: (value) {
                setState(() {
                  scoreChange = value;
                });
              },
            ),

            // 점수 설명
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '매우 나쁨\n(-5.0)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '보통\n(0.0)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '매우 좋음\n(+5.0)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 평가 이유 (선택사항)
            Text(
              '평가 이유 (선택사항)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '평가 이유를 자세히 적어주세요...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // 제출 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: scoreChange != 0.0 ? _submitEvaluation : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '매너 평가 제출',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitEvaluation() async {
    if (scoreChange == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('점수를 변경해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매너 평가 제출'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.rateeName}님에게 다음 평가를 제출하시겠습니까?'),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _getCategoryIcon(selectedCategory),
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(_getCategoryName(selectedCategory)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '점수 변경: ${scoreChange > 0 ? '+' : ''}${scoreChange.toStringAsFixed(1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scoreChange > 0 ? Colors.green : Colors.red,
              ),
            ),
            if (_reasonController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '이유: ${_reasonController.text}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('제출'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context.read<BuddyCubit>().createMannerLog(
            rateeId: widget.rateeId,
            signalId: widget.signalId,
            scoreChange: scoreChange,
            category: selectedCategory,
            reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
          );

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.rateeName}님에게 매너 평가를 제출했습니다'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매너 평가 제출에 실패했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'punctuality':
        return Icons.access_time;
      case 'communication':
        return Icons.chat_bubble_outline;
      case 'kindness':
        return Icons.favorite_outline;
      case 'participation':
        return Icons.groups;
      default:
        return Icons.star_outline;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'punctuality':
        return '시간 약속';
      case 'communication':
        return '소통';
      case 'kindness':
        return '친절함';
      case 'participation':
        return '참여도';
      default:
        return category;
    }
  }
}