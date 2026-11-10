import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/download_queue_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(downloadQueueProvider);
    final notifier = ref.read(downloadQueueProvider.notifier);

    final pending = queueState.pendingTasks;
    final completed = queueState.completedTasks;
    final activeMap = queueState.activeStates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hàng đợi tải'),
        actions: [
          if (completed.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, color: AppTheme.textSecondary, size: 18),
              label: const Text(
                'Dọn lịch sử',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              onPressed: () => notifier.clearCompleted(),
            ),
        ],
      ),
      body: (pending.isEmpty && completed.isEmpty)
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done, size: 64, color: AppTheme.surfaceLight),
                  SizedBox(height: 16),
                  Text(
                    'Hàng đợi tải đang trống',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  Text(
                    'ĐANG XỬ LÝ & CHỜ TẢI (${pending.length})',
                    style: const TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((task) {
                    final active = activeMap[task.jobId];
                    final isRunning = task.status == 'running' || active != null;
                    final progress = active?.progress ?? task.progress;
                    final speedText = active?.speedFormatted ?? '0.00 MB/s';
                    final etaText = active?.etaFormatted ?? '--:--';
                    final stepText = active?.step ?? task.step;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isRunning
                                        ? AppTheme.neonGreen.withOpacity(0.15)
                                        : AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isRunning
                                        ? Icons.cloud_download
                                        : Icons.hourglass_top,
                                    color: isRunning
                                        ? AppTheme.neonGreen
                                        : AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${task.artist} • ${task.formatId.toUpperCase()}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRunning)
                                  IconButton(
                                    tooltip: 'Ưu tiên tải ngay',
                                    icon: const Icon(Icons.arrow_upward,
                                        color: AppTheme.neonGreen),
                                    onPressed: () =>
                                        notifier.elevatePriority(task.jobId),
                                  ),
                                IconButton(
                                  tooltip: 'Hủy tải',
                                  icon: const Icon(Icons.cancel_outlined,
                                      color: AppTheme.errorRed),
                                  onPressed: () => notifier.cancel(task.jobId),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: isRunning ? (progress / 100.0) : 0.0,
                                minHeight: 6,
                                backgroundColor: AppTheme.surfaceLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isRunning ? AppTheme.neonGreen : AppTheme.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isRunning
                                      ? '${progress.toStringAsFixed(1)}% • $stepText'
                                      : 'Đang chờ lượt (Ưu tiên: ${task.priority})',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (isRunning)
                                  Text(
                                    '$speedText • ETA: $etaText',
                                    style: const TextStyle(
                                      color: AppTheme.neonGreenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (completed.isNotEmpty) ...[
                  Text(
                    'ĐÃ HOÀN TẤT / LỊCH SỬ (${completed.length})',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...completed.map((task) {
                    final isSuccess = task.status == 'completed';
                    final isFailed = task.status == 'failed';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        isSuccess
                            ? Icons.check_circle
                            : (isFailed ? Icons.error : Icons.cancel),
                        color: isSuccess
                            ? AppTheme.neonGreen
                            : (isFailed ? AppTheme.errorRed : AppTheme.textMuted),
                      ),
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        isSuccess
                            ? 'Đã lưu /Music • ${task.formatId.toUpperCase()}'
                            : (isFailed
                                ? 'Lỗi: ${task.error ?? "Không xác định"}'
                                : 'Đã hủy bởi người dùng'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSuccess
                              ? AppTheme.textSecondary
                              : (isFailed ? AppTheme.errorRed : AppTheme.textMuted),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
