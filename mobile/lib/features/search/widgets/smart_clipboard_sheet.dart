import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class SmartClipboardManager {
  static String? _lastCheckedUrl;

  /// Check clipboard for media URLs (YouTube, TikTok, Facebook, Instagram, SoundCloud)
  static Future<String?> checkClipboardForMediaUrl() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();

      if (text == null || text.isEmpty) return null;
      if (text == _lastCheckedUrl) return null; // Avoid repeatedly prompting for the same link

      final isMediaUrl = text.startsWith('http://') || text.startsWith('https://');
      if (!isMediaUrl) return null;

      final supportedDomains = [
        'youtube.com',
        'youtu.be',
        'tiktok.com',
        'facebook.com',
        'fb.watch',
        'instagram.com',
        'soundcloud.com',
      ];

      final isSupported = supportedDomains.any((domain) => text.contains(domain));
      if (isSupported) {
        _lastCheckedUrl = text;
        return text;
      }
    } catch (_) {}
    return null;
  }

  /// Show BottomSheet prompting the user to extract or download the detected URL
  static void showDetectedLinkSheet({
    required BuildContext context,
    required String url,
    required ValueChanged<String> onConfirmExtract,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.content_paste,
                      color: AppTheme.neonGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Phát hiện liên kết Media',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.pureBlack,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.neonGreenAccent,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.surfaceLight),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Bỏ qua',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirmExtract(url);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        foregroundColor: AppTheme.pureBlack,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Bóc tách & Tải',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
