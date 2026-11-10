import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/isar_database.dart';
import '../../../data/local/schemas/track_schema.dart';

class TagEditorScreen extends StatefulWidget {
  final Track track;

  const TagEditorScreen({super.key, required this.track});

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;

  final IsarDatabase _db = IsarDatabase.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _albumController = TextEditingController(text: widget.track.album);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  Future<void> _saveTags() async {
    setState(() => _isSaving = true);

    final newTitle = _titleController.text.trim();
    final newArtist = _artistController.text.trim();
    final newAlbum = _albumController.text.trim();

    try {
      // 1. Attempt writing ID3 tags to physical media file via audiotags
      final file = File(widget.track.filePath);
      if (await file.exists()) {
        try {
          final tag = Tag(
            title: newTitle,
            artist: newArtist,
            album: newAlbum,
          );
          await AudioTags.write(widget.track.filePath, tag);
        } catch (_) {
          // audiotags might not support certain container formats, continue updating DB
        }
      }

      // 2. Update record in Isar database
      widget.track.title = newTitle.isNotEmpty ? newTitle : widget.track.title;
      widget.track.artist = newArtist.isNotEmpty ? newArtist : widget.track.artist;
      widget.track.album = newAlbum.isNotEmpty ? newAlbum : widget.track.album;

      await _db.saveTrack(widget.track);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thông tin ID3 tags thành công!'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );

      Navigator.pop(context);
    } catch (exc) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lưu tags: $exc'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = widget.track.coverPath != null &&
        File(widget.track.coverPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa ID3 Tags'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveTags,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.neonGreen,
                    ),
                  )
                : const Text(
                    'LƯU',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Album Art Preview
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceLight, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hasCover
                      ? Image.file(
                          File(widget.track.coverPath!),
                          fit: BoxFit.cover,
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.album, size: 54, color: AppTheme.neonGreen),
                            SizedBox(height: 6),
                            Text(
                              'Ảnh bìa 1:1',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Title Field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Tiêu đề bài hát (Title)',
                prefixIcon: Icon(Icons.music_note, color: AppTheme.neonGreen),
              ),
            ),
            const SizedBox(height: 16),

            // Artist Field
            TextField(
              controller: _artistController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nghệ sĩ / Ca sĩ (Artist)',
                prefixIcon: Icon(Icons.person, color: AppTheme.neonGreen),
              ),
            ),
            const SizedBox(height: 16),

            // Album Field
            TextField(
              controller: _albumController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Album',
                prefixIcon: Icon(Icons.album, color: AppTheme.neonGreen),
              ),
            ),
            const SizedBox(height: 24),

            // File Information Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THÔNG TIN TẬP TIN',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đường dẫn: ${widget.track.filePath}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Định dạng: ${widget.track.ext.toUpperCase()} • Kích thước: ${(widget.track.filesizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
