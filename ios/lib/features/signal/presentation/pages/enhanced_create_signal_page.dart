import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../data/models/signal.dart';
import '../cubit/signal_create_cubit.dart';
import '../cubit/signal_create_state.dart';
import '../widgets/enhanced_category_selector.dart';
import '../widgets/enhanced_location_picker.dart';

class EnhancedCreateSignalPage extends StatefulWidget {
  final LatLng? initialLocation;

  const EnhancedCreateSignalPage({
    super.key,
    this.initialLocation,
  });

  @override
  State<EnhancedCreateSignalPage> createState() => _EnhancedCreateSignalPageState();
}

class _EnhancedCreateSignalPageState extends State<EnhancedCreateSignalPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form data
  int _currentStep = 0;
  final int _totalSteps = 4;
  String? _selectedCategory;
  DateTime? _selectedDateTime;
  int _maxParticipants = 4;
  int _minAge = 0;
  int _maxAge = 100;
  String _genderPreference = 'any';
  bool _allowInstantJoin = true;
  bool _requireApproval = false;
  LatLng? _selectedLocation;
  String? _address;
  String? _placeName;

  // Validation states
  final Map<int, bool> _stepValidation = {
    0: false,
    1: false,
    2: false,
    3: true,
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeLocation();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  void _initializeLocation() {
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _validateStep(2);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _validateStep(int step) {
    bool isValid = false;
    switch (step) {
      case 0:
        isValid = _selectedCategory != null;
        break;
      case 1:
        isValid = _titleController.text.trim().isNotEmpty &&
                  _titleController.text.trim().length >= 5 &&
                  _selectedDateTime != null &&
                  _selectedDateTime!.isAfter(DateTime.now());
        break;
      case 2:
        isValid = _selectedLocation != null && _address != null;
        break;
      case 3:
        isValid = true;
        break;
    }

    if (_stepValidation[step] != isValid) {
      setState(() {
        _stepValidation[step] = isValid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(theme),
      body: BlocListener<SignalCreateCubit, SignalCreateState>(
        listener: (context, state) {
          if (state.status == SignalCreateStatus.success) {
            HapticFeedback.notificationFeedback(HapticFeedbackType.success);
            _showSuccessDialog();
          } else if (state.status == SignalCreateStatus.failure) {
            HapticFeedback.notificationFeedback(HapticFeedbackType.error);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error ?? '시그널 생성에 실패했습니다'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Column(
          children: [
            _buildProgressIndicator(theme),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCategoryStep(theme),
                    _buildDetailsStep(theme),
                    _buildLocationStep(theme),
                    _buildSettingsStep(theme),
                  ],
                ),
              ),
            ),
            _buildBottomActions(theme),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
        tooltip: '취소',
      ),
      title: Text(
        '시그널 만들기',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _canProceedToNext() ? _handleNext : null,
          child: Text(
            _isLastStep() ? '완료' : '다음',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _canProceedToNext() 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Step indicators
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              final isValid = _stepValidation[index] ?? false;
              
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted || (isActive && isValid)
                              ? theme.colorScheme.primary
                              : isActive
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.outline.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: isActive && !isCompleted
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? Icon(
                                  Icons.check,
                                  color: theme.colorScheme.onPrimary,
                                  size: 18,
                                )
                              : Text(
                                  (index + 1).toString(),
                                  style: TextStyle(
                                    color: isActive
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      if (index < _totalSteps - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: index < _currentStep
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          
          const SizedBox(height: 12),
          
          // Step titles
          Row(
            children: [
              Expanded(
                child: Text(
                  _getStepTitle(_currentStep),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Text(
                '${_currentStep + 1} / $_totalSteps',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            '무엇을 함께 할까요?',
            '관심사를 선택하면 비슷한 취향의 사람들과 연결됩니다',
            Icons.interests,
          ),
          
          const SizedBox(height: 32),
          
          EnhancedCategorySelector(
            selectedCategory: _selectedCategory,
            onCategorySelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
              _validateStep(0);
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              theme,
              '시그널 상세 정보',
              '멋진 제목과 설명으로 사람들의 관심을 끌어보세요',
              Icons.edit_note,
            ),
            
            const SizedBox(height: 32),
            
            // Title input
            _buildInputSection(
              theme,
              '제목',
              '어떤 활동을 함께 하고 싶나요?',
              Icons.title,
              child: TextFormField(
                controller: _titleController,
                decoration: _getInputDecoration(theme, '예: 한강에서 함께 피크닉 해요! 🧺'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  if (value.trim().length < 5) {
                    return '제목은 5자 이상 입력해주세요';
                  }
                  if (value.trim().length > 100) {
                    return '제목은 100자 이하로 입력해주세요';
                  }
                  return null;
                },
                maxLength: 100,
                onChanged: (value) => _validateStep(1),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description input
            _buildInputSection(
              theme,
              '설명 (선택사항)',
              '활동에 대한 상세한 설명을 적어주세요',
              Icons.description,
              child: TextFormField(
                controller: _descriptionController,
                decoration: _getInputDecoration(
                  theme,
                  '예: 맛있는 음식과 함께 한강에서 여유로운 시간을 보내요. 준비물은 제가 챙길게요!',
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return '설명은 500자 이하로 입력해주세요';
                  }
                  return null;
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Date time picker
            _buildDateTimePicker(theme),
            
            const SizedBox(height: 24),
            
            // Participant counter
            _buildParticipantCounter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: _buildStepHeader(
            theme,
            '어디서 만날까요?',
            '지도를 터치해서 만날 장소를 선택해주세요',
            Icons.place,
          ),
        ),
        
        Expanded(
          child: EnhancedLocationPicker(
            initialLocation: _selectedLocation,
            initialAddress: _address,
            initialPlaceName: _placeName,
            onLocationSelected: (location, address, placeName) {
              setState(() {
                _selectedLocation = location;
                _address = address;
                _placeName = placeName;
              });
              _validateStep(2);
              HapticFeedback.lightImpact();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            theme,
            '참여 설정',
            '누가 참여할 수 있는지 설정해주세요',
            Icons.settings,
          ),
          
          const SizedBox(height: 32),
          
          // Age range
          _buildAgeRangeSelector(theme),
          
          const SizedBox(height: 24),
          
          // Gender preference
          _buildGenderPreference(theme),
          
          const SizedBox(height: 24),
          
          // Join settings
          _buildJoinSettings(theme),
          
          const SizedBox(height: 32),
          
          // Summary
          _buildSummary(theme),
        ],
      ),
    );
  }

  Widget _buildStepHeader(ThemeData theme, String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon, {
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  InputDecoration _getInputDecoration(ThemeData theme, String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.error,
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildDateTimePicker(ThemeData theme) {
    return _buildInputSection(
      theme,
      '언제 만날까요?',
      '날짜와 시간을 선택해주세요',
      Icons.schedule,
      child: InkWell(
        onTap: _selectDateTime,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedDateTime != null
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event,
                color: _selectedDateTime != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedDateTime != null
                      ? DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(_selectedDateTime!)
                      : '날짜와 시간을 선택하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDateTime != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantCounter(ThemeData theme) {
    return _buildInputSection(
      theme,
      '참여 인원',
      '나를 포함한 총 참여 인원수를 선택해주세요',
      Icons.people,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _maxParticipants > 2 ? () {
                setState(() => _maxParticipants--);
                HapticFeedback.lightImpact();
              } : null,
              icon: Icon(
                Icons.remove_circle_outline,
                color: _maxParticipants > 2
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            
            Column(
              children: [
                Text(
                  '$_maxParticipants명',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '최대 인원',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            
            IconButton(
              onPressed: _maxParticipants < 20 ? () {
                setState(() => _maxParticipants++);
                HapticFeedback.lightImpact();
              } : null,
              icon: Icon(
                Icons.add_circle_outline,
                color: _maxParticipants < 20
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeRangeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.cake,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '연령대',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('${_minAge}세'),
                  Expanded(
                    child: RangeSlider(
                      values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      labels: RangeLabels('${_minAge}세', '${_maxAge}세'),
                      onChanged: (values) {
                        setState(() {
                          _minAge = values.start.round();
                          _maxAge = values.end.round();
                        });
                      },
                    ),
                  ),
                  Text('${_maxAge}세'),
                ],
              ),
              Text(
                '${_minAge == 0 ? '전체' : '${_minAge}세'} ~ ${_maxAge == 100 ? '전체' : '${_maxAge}세'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderPreference(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.wc,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '성별 선호',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption(theme, 'any', '성별 무관', Icons.people),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGenderOption(theme, 'male', '남성만', Icons.man),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGenderOption(theme, 'female', '여성만', Icons.woman),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(ThemeData theme, String value, String label, IconData icon) {
    final isSelected = _genderPreference == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _genderPreference = value;
        });
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinSettings(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.how_to_reg,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '참가 방식',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Allow instant join
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _allowInstantJoin,
                onChanged: (value) {
                  setState(() {
                    _allowInstantJoin = value;
                    if (value) {
                      _requireApproval = false;
                    }
                  });
                  HapticFeedback.selectionClick();
                },
                title: Text(
                  '즉시 참가 허용',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '신청과 동시에 참가가 확정됩니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              
              if (!_allowInstantJoin) ...[
                const Divider(),
                SwitchListTile(
                  value: _requireApproval,
                  onChanged: (value) {
                    setState(() {
                      _requireApproval = value;
                    });
                    HapticFeedback.selectionClick();
                  },
                  title: Text(
                    '참가 승인 필요',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '호스트가 승인해야 참가가 확정됩니다',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.summarize,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '시그널 요약',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSummaryRow('카테고리', _selectedCategory?.displayName ?? '미선택'),
          _buildSummaryRow('제목', _titleController.text.trim().isEmpty ? '미입력' : _titleController.text.trim()),
          _buildSummaryRow('날짜', _selectedDateTime != null 
              ? DateFormat('M월 d일 HH:mm').format(_selectedDateTime!) : '미선택'),
          _buildSummaryRow('장소', _placeName ?? _address ?? '미선택'),
          _buildSummaryRow('인원', '$_maxParticipants명'),
          _buildSummaryRow('연령', '${_minAge}세 - ${_maxAge}세'),
          _buildSummaryRow('성별', _getGenderDisplayName(_genderPreference)),
          _buildSummaryRow('참가 방식', _allowInstantJoin ? '즉시 참가' : _requireApproval ? '승인 필요' : '자유 참가'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: BlocBuilder<SignalCreateCubit, SignalCreateState>(
        builder: (context, state) {
          return Row(
            children: [
              if (_currentStep > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousStep,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              
              Expanded(
                flex: _currentStep > 0 ? 2 : 1,
                child: ElevatedButton(
                  onPressed: _canProceedToNext() && state.status != SignalCreateStatus.loading 
                      ? _handleNext 
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.status == SignalCreateStatus.loading && _isLastStep()
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('생성 중...'),
                          ],
                        )
                      : Text(
                          _isLastStep() ? '시그널 생성' : '다음',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return '관심사 선택';
      case 1:
        return '상세 정보 입력';
      case 2:
        return '장소 선택';
      case 3:
        return '참여 설정';
      default:
        return '';
    }
  }

  bool _canProceedToNext() {
    return _stepValidation[_currentStep] ?? false;
  }

  bool _isLastStep() => _currentStep == _totalSteps - 1;

  void _handleNext() {
    if (_isLastStep()) {
      _submitSignal();
    } else {
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now.add(const Duration(hours: 1));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (date == null || !mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (time != null && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year, date.month, date.day,
          time.hour, time.minute,
        );
      });
      _validateStep(1);
      HapticFeedback.selectionClick();
    }
  }

  void _submitSignal() {
    if (!_canProceedToNext()) return;
    
    final request = CreateSignalRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory!,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      address: _address ?? '',
      placeName: _placeName,
      scheduledAt: _selectedDateTime!,
      maxParticipants: _maxParticipants,
      minAge: _minAge > 0 ? _minAge : null,
      maxAge: _maxAge < 100 ? _maxAge : null,
      allowInstantJoin: _allowInstantJoin,
      requireApproval: _requireApproval,
      genderPreference: _genderPreference != 'any' ? _genderPreference : null,
    );
    
    context.read<SignalCreateCubit>().createSignal(request);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '시그널 생성 완료!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '멋진 시그널이 생성되었습니다.\n곧 비슷한 관심사를 가진 사람들과 연결될 거예요!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, true); // Close create page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGenderDisplayName(String preference) {
    switch (preference) {
      case 'male':
        return '남성만';
      case 'female':
        return '여성만';
      default:
        return '성별 무관';
    }
  }
}