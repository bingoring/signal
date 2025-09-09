import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../data/models/signal.dart';
import '../cubit/join_request_cubit.dart';

class EnhancedJoinRequestBottomSheet extends StatefulWidget {
  final Signal signal;
  final bool isOwner;
  final int? currentUserId;

  const EnhancedJoinRequestBottomSheet({
    super.key,
    required this.signal,
    required this.isOwner,
    this.currentUserId,
  });

  @override
  State<EnhancedJoinRequestBottomSheet> createState() => _EnhancedJoinRequestBottomSheetState();
}

class _EnhancedJoinRequestBottomSheetState extends State<EnhancedJoinRequestBottomSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.isOwner ? 3 : 1,
      vsync: this,
    );
    
    // 컴포넌트 로드시 참가 신청서 목록 가져오기
    context.read<JoinRequestCubit>().loadJoinRequests(widget.signal.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: BlocListener<JoinRequestCubit, JoinRequestState>(
        listener: (context, state) {
          if (state.submitStatus == SubmitStatus.submitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('참가 신청이 완료되었습니다!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else if (state.submitStatus == SubmitStatus.failed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.submitError ?? '참가 신청에 실패했습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          
          if (state.actionStatus == ActionStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('처리가 완료되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state.actionStatus == ActionStatus.failed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError ?? '처리에 실패했습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildHeader(),
            if (widget.isOwner) _buildTabBar() else _buildJoinForm(),
            if (widget.isOwner)
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingRequests(),
                    _buildApprovedRequests(),
                    _buildRejectedRequests(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.isOwner ? Icons.group : Icons.person_add,
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
                  widget.isOwner ? '참가 신청서 관리' : '시그널 참가하기',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.signal.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: BlocBuilder<JoinRequestCubit, JoinRequestState>(
        builder: (context, state) {
          final cubit = context.read<JoinRequestCubit>();
          final pendingCount = cubit.pendingRequests.length;
          final approvedCount = cubit.approvedRequests.length;
          final rejectedCount = cubit.rejectedRequests.length;
          
          return TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('대기'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pendingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('승인'),
                    if (approvedCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          approvedCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('거절'),
                    if (rejectedCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          rejectedCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJoinForm() {
    final theme = Theme.of(context);
    
    return BlocBuilder<JoinRequestCubit, JoinRequestState>(
      builder: (context, state) {
        // 이미 신청했는지 확인
        final hasRequested = widget.currentUserId != null &&
            context.read<JoinRequestCubit>().hasUserRequested(widget.currentUserId!);
        
        if (hasRequested) {
          final userRequest = context.read<JoinRequestCubit>().getUserRequest(widget.currentUserId!);
          return _buildRequestStatus(userRequest!);
        }
        
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 시그널 정보
              _buildSignalInfo(),
              
              const SizedBox(height: 24),
              
              // 메시지 입력
              Text(
                '간단한 인사말을 남겨보세요 (선택사항)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: '예: 안녕하세요! 함께 즐거운 시간 보내요 😊',
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
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 참가 신청 버튼
              ElevatedButton(
                onPressed: state.submitStatus == SubmitStatus.submitting
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        context.read<JoinRequestCubit>().submitJoinRequest(
                          widget.signal.id,
                          message: _messageController.text.trim().isEmpty
                              ? null
                              : _messageController.text.trim(),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.submitStatus == SubmitStatus.submitting
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
                          const Text('신청 중...'),
                        ],
                      )
                    : const Text(
                        '참가 신청하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              
              const SizedBox(height: 12),
              
              // 주의사항
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '참가 신청 안내',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.signal.requireApproval
                          ? '• 이 시그널은 승인이 필요합니다\n• 호스트가 승인하면 참가가 확정됩니다\n• 매너 있는 소통을 부탁드려요'
                          : '• 즉시 참가가 가능한 시그널입니다\n• 신청과 함께 참가가 확정됩니다\n• 매너 있는 소통을 부탁드려요',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSignalInfo() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '참여 인원: ${widget.signal.currentParticipants}/${widget.signal.maxParticipants}명',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                widget.signal.requireApproval ? Icons.approval : Icons.flash_on,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.signal.requireApproval ? '승인 필요' : '즉시 참가',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestStatus(SignalJoinRequest request) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getStatusColor(request.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getStatusColor(request.status).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getStatusIcon(request.status),
                  size: 48,
                  color: _getStatusColor(request.status),
                ),
                const SizedBox(height: 16),
                Text(
                  _getStatusTitle(request.status),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(request.status),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusMessage(request.status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전달한 메시지',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.message!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingRequests() {
    return BlocBuilder<JoinRequestCubit, JoinRequestState>(
      builder: (context, state) {
        if (state.status == JoinRequestStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final pendingRequests = context.read<JoinRequestCubit>().pendingRequests;
        
        if (pendingRequests.isEmpty) {
          return _buildEmptyState('대기 중인 신청서가 없습니다', Icons.inbox);
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: pendingRequests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final request = pendingRequests[index];
            return _buildRequestCard(request, isPending: true);
          },
        );
      },
    );
  }

  Widget _buildApprovedRequests() {
    return BlocBuilder<JoinRequestCubit, JoinRequestState>(
      builder: (context, state) {
        final approvedRequests = context.read<JoinRequestCubit>().approvedRequests;
        
        if (approvedRequests.isEmpty) {
          return _buildEmptyState('승인된 신청서가 없습니다', Icons.check_circle_outline);
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: approvedRequests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final request = approvedRequests[index];
            return _buildRequestCard(request, isPending: false);
          },
        );
      },
    );
  }

  Widget _buildRejectedRequests() {
    return BlocBuilder<JoinRequestCubit, JoinRequestState>(
      builder: (context, state) {
        final rejectedRequests = context.read<JoinRequestCubit>().rejectedRequests;
        
        if (rejectedRequests.isEmpty) {
          return _buildEmptyState('거절된 신청서가 없습니다', Icons.cancel_outlined);
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rejectedRequests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final request = rejectedRequests[index];
            return _buildRequestCard(request, isPending: false);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(SignalJoinRequest request, {required bool isPending}) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용자 정보
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: request.user?.profile?.profileImageUrl != null
                    ? NetworkImage(request.user!.profile!.profileImageUrl!)
                    : null,
                child: request.user?.profile?.profileImageUrl == null
                    ? Text(
                        request.user?.profile?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.user?.profile?.displayName ?? request.user?.username ?? '사용자',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (request.user?.profile != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${request.user!.profile!.age}세',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '매너점수 ${request.user!.profile!.mannerScore.toStringAsFixed(1)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(request.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(request.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.message!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showApproveDialog(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('승인'),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 8),
          Text(
            '신청일시: ${_formatDateTime(request.createdAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(SignalJoinRequest request) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('신청 승인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.user?.profile?.displayName ?? '사용자'}님의 참가 신청을 승인하시겠습니까?'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: '승인 메시지 (선택사항)',
                hintText: '환영합니다! 함께 즐거운 시간 보내요.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 300,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<JoinRequestCubit>().approveJoinRequest(
                widget.signal.id,
                request.userId,
                message: messageController.text.trim().isEmpty
                    ? null
                    : messageController.text.trim(),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('승인'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(SignalJoinRequest request) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('신청 거절'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.user?.profile?.displayName ?? '사용자'}님의 참가 신청을 거절하는 이유를 알려주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '거절 이유 *',
                hintText: '정원 초과, 연령대 불일치 등',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 300,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: reasonController.text.trim().isNotEmpty
                ? () {
                    context.read<JoinRequestCubit>().rejectJoinRequest(
                      widget.signal.id,
                      request.userId,
                      reasonController.text.trim(),
                    );
                    Navigator.pop(dialogContext);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'expired':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'pending':
        return '승인 대기 중';
      case 'approved':
        return '참가 승인됨!';
      case 'rejected':
        return '참가 거절됨';
      case 'expired':
        return '신청 만료됨';
      default:
        return '알 수 없음';
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'pending':
        return '호스트가 승인하면 참가가 확정됩니다.\n조금만 기다려주세요!';
      case 'approved':
        return '축하합니다! 시그널 참가가 확정되었습니다.\n채팅방에서 다른 참가자들과 소통해보세요.';
      case 'rejected':
        return '아쉽지만 이번 시그널 참가가 거절되었습니다.\n다른 시그널을 찾아보시는 건 어떨까요?';
      case 'expired':
        return '신청 기한이 만료되었습니다.';
      default:
        return '';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'approved':
        return '승인됨';
      case 'rejected':
        return '거절됨';
      case 'expired':
        return '만료됨';
      default:
        return '알수없음';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}