import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController =
      TextEditingController(text: AppConstants.defaultBaseUrl);
  final TextEditingController _apiKeyController =
      TextEditingController(text: AppConstants.defaultApiKey);
  final TextEditingController _cookiesController = TextEditingController();

  final ApiClient _apiClient = ApiClient();
  bool _isTestingHealth = false;
  bool _isSyncingCookies = false;
  String? _healthStatusMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _cookiesController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final newUrl = _urlController.text.trim();
    final newKey = _apiKeyController.text.trim();

    _apiClient.updateBaseUrl(newUrl);
    _apiClient.updateApiKey(newKey);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật cấu hình Server URL & API Key thành công!'),
        backgroundColor: AppTheme.neonGreen,
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingHealth = true;
      _healthStatusMessage = null;
    });

    _apiClient.updateBaseUrl(_urlController.text.trim());
    _apiClient.updateApiKey(_apiKeyController.text.trim());

    final ok = await _apiClient.checkHealth();
    if (!mounted) return;

    setState(() {
      _isTestingHealth = false;
      _healthStatusMessage = ok
          ? 'Kết nối Server thành công! (200 OK)'
          : 'Không thể kết nối đến Server. Vui lòng kiểm tra lại URL hoặc mạng.';
    });
  }

  Future<void> _syncCookies() async {
    final cookiesText = _cookiesController.text.trim();
    if (cookiesText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng dán chuỗi Netscape cookies trước khi đồng bộ!'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSyncingCookies = true);

    try {
      final success = await _apiClient.updateCookies(cookiesText);
      if (!mounted) return;
      setState(() => _isSyncingCookies = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đồng bộ YouTube cookies lên server (/tmp/cookies.txt) thành công!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đồng bộ thất bại. Vui lòng kiểm tra Server.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (exc) {
      if (!mounted) return;
      setState(() => _isSyncingCookies = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi cookies: $exc'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.neonGreen),
            tooltip: 'Lưu cấu hình',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Server URL & Auth
            const Text(
              'MÁY CHỦ HUGGING FACE SPACES',
              style: TextStyle(
                color: AppTheme.neonGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Server Base URL',
                prefixIcon: Icon(Icons.dns, color: AppTheme.neonGreen),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _apiKeyController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'API Key (X-API-Key)',
                prefixIcon: Icon(Icons.vpn_key, color: AppTheme.neonGreen),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingHealth ? null : _testConnection,
                    icon: _isTestingHealth
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.pureBlack,
                            ),
                          )
                        : const Icon(Icons.network_check),
                    label: const Text('Kiểm tra kết nối'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceDark,
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.neonGreen, width: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    foregroundColor: AppTheme.pureBlack,
                  ),
                  child: const Text('Lưu'),
                ),
              ],
            ),
            if (_healthStatusMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _healthStatusMessage!,
                style: TextStyle(
                  color: _healthStatusMessage!.contains('thành công')
                      ? AppTheme.neonGreenAccent
                      : AppTheme.errorRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Divider(color: AppTheme.surfaceLight, height: 36),

            // Section 2: Cookies Anti-bot
            const Text(
              'YOUTUBE COOKIES (CHỐNG CHẶN BOT)',
              style: TextStyle(
                color: AppTheme.neonGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dán nội dung file cookies Netscape format (.txt) để giải quyết lỗi "Sign in to confirm you\'re not a bot".',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cookiesController,
              maxLines: 6,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              decoration: InputDecoration(
                hintText: '# Netscape HTTP Cookie File\n.youtube.com  TRUE  /  TRUE  ...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, color: AppTheme.neonGreen),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _cookiesController.text = data!.text!.trim();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncingCookies ? null : _syncCookies,
                icon: _isSyncingCookies
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.pureBlack,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: const Text('Đồng bộ lên Server (/tmp/cookies.txt)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: AppTheme.pureBlack,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
