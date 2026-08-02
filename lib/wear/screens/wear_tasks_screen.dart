import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/task_provider.dart';
import '../wear_utils.dart';

/// Việc của tôi trên đồng hồ — dạng todolist tối giản: chỉ tiêu đề + trạng thái.
///
/// Không giao việc, không nộp minh chứng, không duyệt: đó là việc của app điện
/// thoại. Đồng hồ chỉ để liếc xem còn việc gì.
class WearTasksScreen extends StatefulWidget {
  const WearTasksScreen({super.key});

  @override
  State<WearTasksScreen> createState() => _WearTasksScreenState();
}

class _WearTasksScreenState extends State<WearTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TaskProvider>().fetchMyAssignments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = WearUtils.safePadding(context);
    final all = context.watch<TaskProvider>().myAssignments;
    // Việc đã xong/hủy không cần chiếm chỗ trên màn hình bé.
    final todo = all
        .where((a) => a.status != 'APPROVED' && a.status != 'CANCELED')
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding.left, 10, padding.right, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.checklist_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Viec cua toi',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${todo.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: todo.isEmpty
                    ? const Center(
                        child: Text(
                          'Khong con viec nao',
                          style: TextStyle(fontSize: 9, color: Colors.white38),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: todo.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 5),
                        itemBuilder: (_, i) => _row(todo[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(TaskAssignment a) {
    final title = a.taskTitle ?? a.task?.title ?? 'Nhiem vu';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: a.statusColor,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            a.statusLabel,
            style: const TextStyle(fontSize: 7.5, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
