import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_interceptors.dart';
import '../../../core/theme/app_theme.dart';

class DebugLoggerScreen extends StatefulWidget {
  const DebugLoggerScreen({super.key});

  @override
  State<DebugLoggerScreen> createState() => _DebugLoggerScreenState();
}

class _DebugLoggerScreenState extends State<DebugLoggerScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = DebugLogStore.instance.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký lỗi bí mật (Debug Logs)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép toàn bộ',
            onPressed: () {
              final allLogs = logs.join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép toàn bộ nhật ký lỗi vào bộ nhớ tạm!'),
                  backgroundColor: AppTheme.neonGreen,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xóa nhật ký',
            onPressed: () {
              setState(() {
                DebugLogStore.instance.clear();
              });
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text(
                'Chưa ghi nhận lỗi hoặc sự kiện mạng nào.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final logLine = logs[logs.length - 1 - index]; // latest first
                final isError = logLine.contains('ERROR') || logLine.contains('failed');

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isError
                        ? AppTheme.errorRed.withOpacity(0.12)
                        : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isError
                          ? AppTheme.errorRed.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    logLine,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isError ? AppTheme.errorRed : AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
