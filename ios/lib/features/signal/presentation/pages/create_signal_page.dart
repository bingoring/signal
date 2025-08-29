import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/location_service.dart';
import '../../data/models/signal.dart';
import '../cubit/signal_create_cubit.dart';
import '../cubit/signal_create_state.dart';
import '../widgets/category_selector.dart';
import '../widgets/location_picker.dart';
import '../widgets/signal_settings_panel.dart';

class CreateSignalPage extends StatefulWidget {
  final LatLng? initialLocation;

  const CreateSignalPage({
    super.key,
    this.initialLocation,
  });

  @override
  State<CreateSignalPage> createState() => _CreateSignalPageState();
}

class _CreateSignalPageState extends State<CreateSignalPage> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageController = PageController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form data
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _getAddressFromLocation(widget.initialLocation!);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _getAddressFromLocation(LatLng location) async {
    // TODO: 역지오코딩으로 주소 가져오기
    setState(() {
      _address = "${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('시그널 보내기'),
        elevation: 0,
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('이전'),
            ),
          TextButton(
            onPressed: _canProceed() ? (_isLastStep() ? _submitSignal : _nextStep) : null,
            child: Text(_isLastStep() ? '완료' : '다음'),
          ),
        ],
      ),
      body: BlocListener<SignalCreateCubit, SignalCreateState>(
        listener: (context, state) {
          if (state.status == SignalCreateStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('시그널이 생성되었습니다!')),
            );
            Navigator.pop(context, state.createdSignal);
          } else if (state.status == SignalCreateStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error ?? '시그널 생성에 실패했습니다')),
            );
          }
        },
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCategoryStep(),
                    _buildDetailsStep(),
                    _buildLocationStep(),
                    _buildSettingsStep(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                  ? Theme.of(context).primaryColor
                  : isCompleted
                    ? Theme.of(context).primaryColor.withOpacity(0.5)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '무엇을 함께 할까요?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            '관심사를 선택하면 비슷한 취향의 사람들과 연결됩니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 32),
          
          CategorySelector(
            selectedCategory: _selectedCategory,
            onCategorySelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '시그널 상세 정보',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '어떤 활동을 함께 하고 싶나요?',
                prefixIcon: Icon(Icons.title),
              ),
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
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명 (선택사항)',
                hintText: '활동에 대한 상세한 설명을 적어주세요',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              maxLength: 500,
              validator: (value) {
                if (value != null && value.length > 500) {
                  return '설명은 500자 이하로 입력해주세요';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            _buildDateTimePicker(),
            
            const SizedBox(height: 24),
            
            _buildParticipantCounter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '어디서 만날까요?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                '지도를 터치해서 만날 장소를 선택해주세요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: LocationPicker(
            initialLocation: _selectedLocation,
            onLocationSelected: (location, address, placeName) {
              setState(() {
                _selectedLocation = location;
                _address = address;
                _placeName = placeName;
              });
            },
          ),
        ),
        
        if (_selectedLocation != null && _address != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_placeName != null)
                        Text(
                          _placeName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        _address!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참여 설정',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          SignalSettingsPanel(
            minAge: _minAge,
            maxAge: _maxAge,
            genderPreference: _genderPreference,
            allowInstantJoin: _allowInstantJoin,
            requireApproval: _requireApproval,
            onMinAgeChanged: (value) => setState(() => _minAge = value),
            onMaxAgeChanged: (value) => setState(() => _maxAge = value),
            onGenderPreferenceChanged: (value) => setState(() => _genderPreference = value),
            onAllowInstantJoinChanged: (value) => setState(() => _allowInstantJoin = value),
            onRequireApprovalChanged: (value) => setState(() => _requireApproval = value),
          ),
          
          const SizedBox(height: 32),
          
          // 요약 정보
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '언제 만날까요?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 12),
        
        InkWell(
          onTap: _selectDateTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDateTime != null
                      ? DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(_selectedDateTime!)
                      : '날짜와 시간을 선택하세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDateTime != null ? null : Colors.grey[600],
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '참여 인원',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _maxParticipants > 2 ? () {
                  setState(() => _maxParticipants--);
                } : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              
              Text(
                '$_maxParticipants명',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              IconButton(
                onPressed: _maxParticipants < 20 ? () {
                  setState(() => _maxParticipants++);
                } : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          '나를 포함하여 최대 $_maxParticipants명이 참여할 수 있습니다',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시그널 요약',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          _buildSummaryRow('카테고리', _getCategoryDisplayName(_selectedCategory)),
          _buildSummaryRow('제목', _titleController.text.isNotEmpty ? _titleController.text : '미입력'),
          _buildSummaryRow('날짜', _selectedDateTime != null 
            ? DateFormat('M월 d일 HH:mm').format(_selectedDateTime!) : '미선택'),
          _buildSummaryRow('장소', _address ?? '미선택'),
          _buildSummaryRow('인원', '$_maxParticipants명'),
          _buildSummaryRow('연령', '${_minAge}세 - ${_maxAge}세'),
          _buildSummaryRow('성별', _getGenderDisplayName(_genderPreference)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now.add(const Duration(hours: 1));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    
    if (date == null) return;
    
    if (mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      
      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year, date.month, date.day,
            time.hour, time.minute,
          );
        });
      }
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedCategory != null;
      case 1:
        return _titleController.text.trim().isNotEmpty && 
               _selectedDateTime != null &&
               _formKey.currentState?.validate() == true;
      case 2:
        return _selectedLocation != null;
      case 3:
        return true;
      default:
        return false;
    }
  }

  bool _isLastStep() => _currentStep == _totalSteps - 1;

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
    }
  }

  void _submitSignal() {
    if (!_canProceed()) return;
    
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

  String _getCategoryDisplayName(String? category) {
    if (category == null) return '미선택';
    switch (category) {
      case 'sports': return '스포츠';
      case 'food': return '맛집';
      case 'culture': return '문화';
      case 'study': return '스터디';
      case 'hobby': return '취미';
      case 'travel': return '여행';
      case 'shopping': return '쇼핑';
      case 'entertainment': return '엔터테인먼트';
      default: return category;
    }
  }

  String _getGenderDisplayName(String preference) {
    switch (preference) {
      case 'male': return '남성만';
      case 'female': return '여성만';
      default: return '성별 무관';
    }
  }
}