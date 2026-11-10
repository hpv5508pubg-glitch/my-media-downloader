import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/sleep_timer_provider.dart';
import '../services/sleep_timer_service.dart';

class SleepTimerDialog extends ConsumerWidget {
  const SleepTimerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(sleepTimerProvider);
    final timerNotifier = ref.read(sleepTimerProvider.notifier);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.bedtime, color: AppTheme.neonGreen),
          SizedBox(width: 8),
          Text(
            'Hẹn giờ tắt nhạc',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timerState.isActive) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neonGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.neonGreen),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: AppTheme.neonGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    timerState.mode == SleepTimerMode.endOfTrack
                        ? 'Dừng khi hết bài này (Fade-out 5s)'
                        : 'Còn lại: ${timerState.formattedRemaining} (Fade-out 5s)',
                    style: const TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildOptionTile(
            context,
            label: '15 phút',
            onTap: () {
              timerNotifier.startTimer(const Duration(minutes: 15));
              Navigator.pop(context);
            },
          ),
          _buildOptionTile(
            context,
            label: '30 phút',
            onTap: () {
              timerNotifier.startTimer(const Duration(minutes: 30));
              Navigator.pop(context);
            },
          ),
          _buildOptionTile(
            context,
            label: '45 phút',
            onTap: () {
              timerNotifier.startTimer(const Duration(minutes: 45));
              Navigator.pop(context);
            },
          ),
          _buildOptionTile(
            context,
            label: '60 phút',
            onTap: () {
              timerNotifier.startTimer(const Duration(minutes: 60));
              Navigator.pop(context);
            },
          ),
          _buildOptionTile(
            context,
            label: 'Khi phát hết bài hát này',
            onTap: () {
              timerNotifier.setEndOfTrack();
              Navigator.pop(context);
            },
          ),
          if (timerState.isActive)
            _buildOptionTile(
              context,
              label: 'Hủy hẹn giờ',
              isDestructive: true,
              onTap: () {
                timerNotifier.cancel();
                Navigator.pop(context);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? AppTheme.errorRed : AppTheme.textPrimary,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
      onTap: onTap,
    );
  }
}
