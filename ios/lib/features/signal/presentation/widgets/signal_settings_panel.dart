import 'package:flutter/material.dart';

class SignalSettingsPanel extends StatefulWidget {
  final int minAge;
  final int maxAge;
  final String genderPreference;
  final bool requiresApproval;
  final bool isPrivate;
  final Function(int, int) onAgeRangeChanged;
  final Function(String) onGenderPreferenceChanged;
  final Function(bool) onRequiresApprovalChanged;
  final Function(bool) onPrivacyChanged;

  const SignalSettingsPanel({
    Key? key,
    required this.minAge,
    required this.maxAge,
    required this.genderPreference,
    required this.requiresApproval,
    required this.isPrivate,
    required this.onAgeRangeChanged,
    required this.onGenderPreferenceChanged,
    required this.onRequiresApprovalChanged,
    required this.onPrivacyChanged,
  }) : super(key: key);

  @override
  State<SignalSettingsPanel> createState() => _SignalSettingsPanelState();
}

class _SignalSettingsPanelState extends State<SignalSettingsPanel>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
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
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildAgeRangeSection(),
              const SizedBox(height: 32),
              _buildGenderPreferenceSection(),
              const SizedBox(height: 32),
              _buildApprovalSection(),
              const SizedBox(height: 32),
              _buildPrivacySection(),
              const SizedBox(height: 32),
              _buildSummarySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시그널 설정',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '원하는 참여자 조건과 시그널 설정을 선택해주세요',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildAgeRangeSection() {
    return _buildSectionCard(
      title: '연령대',
      icon: Icons.cake,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.minAge}세 - ${widget.maxAge}세',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: RangeValues(
              widget.minAge.toDouble(),
              widget.maxAge.toDouble(),
            ),
            min: 18,
            max: 65,
            divisions: 47,
            labels: RangeLabels(
              '${widget.minAge}세',
              '${widget.maxAge}세',
            ),
            onChanged: (RangeValues values) {
              widget.onAgeRangeChanged(
                values.start.round(),
                values.end.round(),
              );
            },
            activeColor: Theme.of(context).primaryColor,
            inactiveColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '18세',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '65세',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPreferenceSection() {
    return _buildSectionCard(
      title: '성별 선호',
      icon: Icons.people,
      child: Column(
        children: [
          _buildGenderOption('any', '성별 무관', Icons.people),
          const SizedBox(height: 12),
          _buildGenderOption('male', '남성만', Icons.male),
          const SizedBox(height: 12),
          _buildGenderOption('female', '여성만', Icons.female),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = widget.genderPreference == value;
    
    return GestureDetector(
      onTap: () => widget.onGenderPreferenceChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalSection() {
    return _buildSectionCard(
      title: '참여 승인',
      icon: Icons.how_to_reg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '참여 승인 필요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.requiresApproval 
                          ? '참여 요청 시 승인이 필요합니다'
                          : '누구나 바로 참여할 수 있습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.requiresApproval,
                onChanged: widget.onRequiresApprovalChanged,
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    return _buildSectionCard(
      title: '공개 설정',
      icon: Icons.privacy_tip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '비공개 시그널',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isPrivate 
                          ? '초대받은 사용자만 참여할 수 있습니다'
                          : '모든 사용자가 검색하고 참여할 수 있습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.isPrivate,
                onChanged: widget.onPrivacyChanged,
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                '설정 요약',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryItem(
            '연령대',
            '${widget.minAge}세 - ${widget.maxAge}세',
            Icons.cake,
          ),
          const SizedBox(height: 8),
          _buildSummaryItem(
            '성별 선호',
            _getGenderPreferenceText(widget.genderPreference),
            Icons.people,
          ),
          const SizedBox(height: 8),
          _buildSummaryItem(
            '참여 승인',
            widget.requiresApproval ? '승인 필요' : '바로 참여',
            Icons.how_to_reg,
          ),
          const SizedBox(height: 8),
          _buildSummaryItem(
            '공개 설정',
            widget.isPrivate ? '비공개' : '공개',
            Icons.privacy_tip,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getGenderPreferenceText(String preference) {
    switch (preference) {
      case 'male':
        return '남성만';
      case 'female':
        return '여성만';
      case 'any':
      default:
        return '성별 무관';
    }
  }
}