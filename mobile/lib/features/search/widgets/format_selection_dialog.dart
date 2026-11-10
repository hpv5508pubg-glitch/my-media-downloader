import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/format_item.dart';
import '../../../data/models/video_item.dart';

class FormatSelectionResult {
  final FormatItem format;
  final bool isPriority;

  const FormatSelectionResult({
    required this.format,
    required this.isPriority,
  });
}

class FormatSelectionDialog extends StatefulWidget {
  final VideoItem video;

  const FormatSelectionDialog({super.key, required this.video});

  @override
  State<FormatSelectionDialog> createState() => _FormatSelectionDialogState();
}

class _FormatSelectionDialogState extends State<FormatSelectionDialog> {
  late FormatItem _selectedFormat;
  bool _isPriority = false;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.video.defaultAudioFormat ??
        (widget.video.formats.isNotEmpty
            ? widget.video.formats.first
            : const FormatItem(
                formatId: 'mp3_320',
                type: 'audio',
                quality: '320kbps',
                ext: 'mp3',
                filesizeMb: 8.5,
                needsFfmpeg: true,
              ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn định dạng tải về',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.video.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.video.formats.map((format) {
              final isSelected = format.formatId == _selectedFormat.formatId;
              final isAudio = format.type == 'audio';
              final isMute = format.type == 'video_mute';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.neonGreen.withOpacity(0.12)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.neonGreen : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: RadioListTile<FormatItem>(
                  value: format,
                  groupValue: _selectedFormat,
                  activeColor: AppTheme.neonGreen,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedFormat = val);
                    }
                  },
                  title: Row(
                    children: [
                      Icon(
                        isAudio
                            ? Icons.music_note
                            : (isMute ? Icons.volume_off : Icons.videocam),
                        color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        format.quality.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? AppTheme.neonGreen : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.pureBlack,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          format.ext.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '~${format.filesizeMb.toStringAsFixed(1)} MB',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ),
              );
            }),
            const Divider(color: AppTheme.surfaceLight, height: 24),
            CheckboxListTile(
              value: _isPriority,
              activeColor: AppTheme.neonGreen,
              checkColor: AppTheme.pureBlack,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ưu tiên tải ngay (Đẩy lên đầu hàng đợi)',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              onChanged: (val) {
                setState(() => _isPriority = val ?? false);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              FormatSelectionResult(
                format: _selectedFormat,
                isPriority: _isPriority,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neonGreen,
            foregroundColor: AppTheme.pureBlack,
          ),
          child: const Text('Bắt đầu tải'),
        ),
      ],
    );
  }
}
