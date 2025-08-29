import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:signal_app/features/signal/domain/entities/signal.dart';
import 'package:signal_app/features/signal/presentation/cubit/signal_edit_cubit.dart';
import 'package:signal_app/features/signal/presentation/widgets/category_selector.dart';
import 'package:signal_app/features/signal/presentation/widgets/location_picker.dart';
import 'package:signal_app/features/signal/presentation/widgets/signal_settings_panel.dart';

class EditSignalPage extends StatefulWidget {
  final Signal signal;

  const EditSignalPage({
    Key? key,
    required this.signal,
  }) : super(key: key);

  @override
  State<EditSignalPage> createState() => _EditSignalPageState();
}

class _EditSignalPageState extends State<EditSignalPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _saveAnimationController;
  late Animation<double> _saveButtonAnimation;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupAnimations();
    _initializeFields();
  }

  void _setupControllers() {
    _tabController = TabController(length: 3, vsync: this);
  }

  void _setupAnimations() {
    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _saveButtonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _saveAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializeFields() {
    _titleController.text = widget.signal.title;
    _descriptionController.text = widget.signal.description;
    
    // Initialize cubit with current signal data
    context.read<SignalEditCubit>().initializeWithSignal(widget.signal);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _saveAnimationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignalEditCubit, SignalEditState>(
      listener: (context, state) {
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('시그널이 수정되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate successful edit
        } else if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(),
                    _buildLocationTab(),
                    _buildSettingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomActions(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '시그널 수정',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      actions: [
        BlocBuilder<SignalEditCubit, SignalEditState>(
          builder: (context, state) {
            return TextButton(
              onPressed: state.isLoading ? null : _onSave,
              child: Text(
                '저장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: state.canSave 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Theme.of(context).primaryColor,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
        labelWeight: FontWeight.bold,
        tabs: const [
          Tab(
            icon: Icon(Icons.info),
            text: '기본정보',
          ),
          Tab(
            icon: Icon(Icons.location_on),
            text: '장소',
          ),
          Tab(
            icon: Icon(Icons.settings),
            text: '설정',
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('카테고리', Icons.category),
          const SizedBox(height: 16),
          BlocBuilder<SignalEditCubit, SignalEditState>(
            buildWhen: (previous, current) => previous.category != current.category,
            builder: (context, state) {
              return CategorySelector(
                selectedCategory: state.category,
                onCategorySelected: (category) {
                  context.read<SignalEditCubit>().updateCategory(category);
                },
              );
            },
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('제목', Icons.title),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '시그널 제목을 입력하세요',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '제목을 입력해주세요';
              }
              if (value.trim().length < 5) {
                return '제목은 5자 이상 입력해주세요';
              }
              return null;
            },
            onChanged: (value) {
              context.read<SignalEditCubit>().updateTitle(value);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('설명', Icons.description),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '시그널에 대한 자세한 설명을 입력하세요',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '설명을 입력해주세요';
              }
              if (value.trim().length < 10) {
                return '설명은 10자 이상 입력해주세요';
              }
              return null;
            },
            onChanged: (value) {
              context.read<SignalEditCubit>().updateDescription(value);
            },
          ),
          const SizedBox(height: 24),
          _buildDateTimeSection(),
          const SizedBox(height: 24),
          _buildMaxParticipantsSection(),
        ],
      ),
    );
  }

  Widget _buildLocationTab() {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<SignalEditCubit, SignalEditState>(
            buildWhen: (previous, current) => 
                previous.latitude != current.latitude ||
                previous.longitude != current.longitude ||
                previous.address != current.address,
            builder: (context, state) {
              return LocationPicker(
                selectedLocation: LatLng(state.latitude, state.longitude),
                selectedAddress: state.address,
                onLocationSelected: (location, address) {
                  context.read<SignalEditCubit>().updateLocation(
                    location.latitude,
                    location.longitude,
                    address,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return BlocBuilder<SignalEditCubit, SignalEditState>(
      buildWhen: (previous, current) => 
          previous.minAge != current.minAge ||
          previous.maxAge != current.maxAge ||
          previous.genderPreference != current.genderPreference ||
          previous.requiresApproval != current.requiresApproval ||
          previous.isPrivate != current.isPrivate,
      builder: (context, state) {
        return SignalSettingsPanel(
          minAge: state.minAge,
          maxAge: state.maxAge,
          genderPreference: state.genderPreference,
          requiresApproval: state.requiresApproval,
          isPrivate: state.isPrivate,
          onAgeRangeChanged: (minAge, maxAge) {
            context.read<SignalEditCubit>().updateAgeRange(minAge, maxAge);
          },
          onGenderPreferenceChanged: (preference) {
            context.read<SignalEditCubit>().updateGenderPreference(preference);
          },
          onRequiresApprovalChanged: (requires) {
            context.read<SignalEditCubit>().updateRequiresApproval(requires);
          },
          onPrivacyChanged: (isPrivate) {
            context.read<SignalEditCubit>().updatePrivacy(isPrivate);
          },
        );
      },
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('모임 일시', Icons.schedule),
        const SizedBox(height: 16),
        BlocBuilder<SignalEditCubit, SignalEditState>(
          buildWhen: (previous, current) => previous.scheduledAt != current.scheduledAt,
          builder: (context, state) {
            return InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.scheduledAt != null
                            ? _formatDateTime(state.scheduledAt!)
                            : '날짜와 시간을 선택하세요',
                        style: TextStyle(
                          fontSize: 16,
                          color: state.scheduledAt != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMaxParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('최대 참여 인원', Icons.people),
        const SizedBox(height: 16),
        BlocBuilder<SignalEditCubit, SignalEditState>(
          buildWhen: (previous, current) => previous.maxParticipants != current.maxParticipants,
          builder: (context, state) {
            return Row(
              children: [
                IconButton(
                  onPressed: state.maxParticipants > 2
                      ? () => context.read<SignalEditCubit>().updateMaxParticipants(state.maxParticipants - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${state.maxParticipants}명',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: state.maxParticipants < 20
                      ? () => context.read<SignalEditCubit>().updateMaxParticipants(state.maxParticipants + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
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
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: BlocBuilder<SignalEditCubit, SignalEditState>(
              builder: (context, state) {
                return AnimatedBuilder(
                  animation: _saveButtonAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _saveButtonAnimation.value,
                      child: ElevatedButton(
                        onPressed: state.isLoading ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                '저장',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _selectDateTime() async {
    final now = DateTime.now();
    final currentState = context.read<SignalEditCubit>().state;
    
    final date = await showDatePicker(
      context: context,
      initialDate: currentState.scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          currentState.scheduledAt ?? now.add(const Duration(hours: 1)),
        ),
      );

      if (time != null && mounted) {
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (dateTime.isAfter(now)) {
          context.read<SignalEditCubit>().updateScheduledAt(dateTime);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('과거 시간은 선택할 수 없습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  void _onCancel() {
    if (context.read<SignalEditCubit>().state.hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('편집 취소'),
          content: const Text('변경사항이 있습니다. 정말 취소하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('계속 편집'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0); // Go to basic info tab
      return;
    }

    _saveAnimationController.forward().then((_) {
      _saveAnimationController.reverse();
    });

    context.read<SignalEditCubit>().saveSignal();
  }
}