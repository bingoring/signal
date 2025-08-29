import 'package:flutter/material.dart';

class BuddySearchFilter extends StatefulWidget {
  final Function(Map<String, dynamic>) onFilter;

  const BuddySearchFilter({
    super.key,
    required this.onFilter,
  });

  @override
  State<BuddySearchFilter> createState() => _BuddySearchFilterState();
}

class _BuddySearchFilterState extends State<BuddySearchFilter> {
  String? selectedStatus;
  String selectedSortBy = 'last_interaction';
  String selectedSortOrder = 'desc';
  double minCompatibility = 0.0;
  int minInteractions = 0;

  final List<String> statusOptions = [
    'active',
    'paused',
    'blocked',
  ];

  final List<Map<String, String>> sortOptions = [
    {'value': 'last_interaction', 'label': '마지막 활동'},
    {'value': 'created_at', 'label': '추가 날짜'},
    {'value': 'compatibility_score', 'label': '궁합 점수'},
    {'value': 'interaction_count', 'label': '상호작용 수'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '필터 및 정렬',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('초기화'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 상태 필터
          Text(
            '상태',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('전체'),
                selected: selectedStatus == null,
                onSelected: (selected) {
                  setState(() {
                    selectedStatus = selected ? null : selectedStatus;
                  });
                },
              ),
              ...statusOptions.map((status) {
                return FilterChip(
                  label: Text(_getStatusText(status)),
                  selected: selectedStatus == status,
                  onSelected: (selected) {
                    setState(() {
                      selectedStatus = selected ? status : null;
                    });
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // 정렬 옵션
          Text(
            '정렬 기준',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedSortBy,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: sortOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option['value'],
                child: Text(option['label']!),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedSortBy = value;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // 정렬 순서
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('내림차순'),
                  value: 'desc',
                  groupValue: selectedSortOrder,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedSortOrder = value;
                      });
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('오름차순'),
                  value: 'asc',
                  groupValue: selectedSortOrder,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedSortOrder = value;
                      });
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 최소 궁합 점수
          Text(
            '최소 궁합 점수: ${minCompatibility.toStringAsFixed(1)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Slider(
            value: minCompatibility,
            min: 0.0,
            max: 10.0,
            divisions: 100,
            onChanged: (value) {
              setState(() {
                minCompatibility = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // 최소 상호작용 수
          Text(
            '최소 상호작용 수',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '0',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                minInteractions = int.tryParse(value) ?? 0;
              });
            },
          ),
          const SizedBox(height: 24),

          // 적용 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('필터 적용'),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '활성';
      case 'paused':
        return '일시정지';
      case 'blocked':
        return '차단됨';
      default:
        return status;
    }
  }

  void _resetFilters() {
    setState(() {
      selectedStatus = null;
      selectedSortBy = 'last_interaction';
      selectedSortOrder = 'desc';
      minCompatibility = 0.0;
      minInteractions = 0;
    });
  }

  void _applyFilters() {
    final filters = <String, dynamic>{
      'sortBy': selectedSortBy,
      'sortOrder': selectedSortOrder,
    };

    if (selectedStatus != null) {
      filters['status'] = selectedStatus;
    }

    if (minCompatibility > 0) {
      filters['minCompatibility'] = minCompatibility;
    }

    if (minInteractions > 0) {
      filters['minInteractions'] = minInteractions;
    }

    widget.onFilter(filters);
  }
}