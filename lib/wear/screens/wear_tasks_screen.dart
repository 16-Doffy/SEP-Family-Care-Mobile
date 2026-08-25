import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/task_provider.dart';
import '../wear_widgets.dart';

class WearTasksScreen extends StatefulWidget {
  const WearTasksScreen({super.key});

  @override
  State<WearTasksScreen> createState() => _WearTasksScreenState();
}

class _WearTasksScreenState extends State<WearTasksScreen> {
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TaskProvider>().fetchMyAssignments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = context.watch<TaskProvider>();
    final todo = taskState.myAssignments
        .where((a) => a.status != 'APPROVED' && a.status != 'CANCELED')
        .toList();

    return WearPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WearHeader(
            icon: Icons.checklist_rounded,
            label: 'Nhiệm vụ',
            color: WearPalette.amber,
            trailing: Text(
              '${todo.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: WearPalette.amber,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 6),
          ],
          if (taskState.loading && todo.isEmpty)
            const WearEmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Đang tải task',
              color: WearPalette.amber,
            )
          else if (todo.isEmpty)
            const WearEmptyState(
              icon: Icons.done_all_rounded,
              title: 'Không còn việc',
              subtitle: 'Mở mobile để xem chi tiết',
              color: WearPalette.green,
            )
          else
            ...todo.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _taskTile(taskState, item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _taskTile(TaskProvider taskState, TaskAssignment item) {
    final title = item.taskTitle ?? item.task?.title ?? 'Nhiệm vụ';
    final due = _dueLabel(item.dueAt);
    final canStart = item.status == 'PENDING';
    final busy = _busyId == item.id;

    return WearTile(
      icon: item.status == 'IN_PROGRESS'
          ? Icons.timelapse_rounded
          : Icons.radio_button_unchecked_rounded,
      title: title,
      subtitle: due.isEmpty
          ? _statusLabel(item.status)
          : '$due - ${_statusLabel(item.status)}',
      color: _wearStatusColor(item),
      filled: item.status == 'IN_PROGRESS',
      trailing: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WearPalette.amber,
              ),
            )
          : canStart
          ? const Icon(Icons.play_arrow_rounded, color: WearPalette.amber)
          : Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _wearStatusColor(item),
              ),
            ),
      onTap: canStart && !busy ? () => _startTask(taskState, item.id) : null,
    );
  }

  Future<void> _startTask(TaskProvider taskState, String id) async {
    HapticFeedback.lightImpact();
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await taskState.startAssignment(id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Color _wearStatusColor(TaskAssignment item) {
    return switch (item.status) {
      'IN_PROGRESS' => WearPalette.blue,
      'SUBMITTED' => WearPalette.violet,
      'REJECTED' || 'UNAVAILABLE' => WearPalette.sosSoft,
      _ => WearPalette.amber,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'PENDING' || 'ASSIGNED' => 'Chờ làm',
      'IN_PROGRESS' => 'Đang làm',
      'SUBMITTED' => 'Chờ duyệt',
      'APPROVED' => 'Hoàn thành',
      'REJECTED' => 'Từ chối',
      'CANCELED' => 'Đã hủy',
      'UNAVAILABLE' => 'Báo bận',
      _ => 'Chờ làm',
    };
  }

  String _dueLabel(DateTime? dueAt) {
    if (dueAt == null) return '';
    final now = DateTime.now();
    final local = dueAt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Hôm nay';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day) {
      return 'Ngày mai';
    }
    return '${local.day}/${local.month}';
  }
}
