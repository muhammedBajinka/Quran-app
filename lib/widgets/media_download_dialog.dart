import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/audio/media_item.dart';
import '../services/media_download.dart';

class MediaDownloadDialog extends StatefulWidget {
  final MediaItem item;
  const MediaDownloadDialog({super.key, required this.item});

  @override
  State<MediaDownloadDialog> createState() => _MediaDownloadDialogState();
}

class _MediaDownloadDialogState extends State<MediaDownloadDialog> {
  final _download = MediaDownload();
  Uint8List? _bytes;
  int _received = 0;
  int? _total;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final data = await _download.fetch(
        Uri.parse(widget.item.videoUrl ?? widget.item.audioUrl!),
        (received, total) {
          if (mounted) setState(() { _received = received; _total = total; });
        },
      );
      if (mounted) setState(() => _bytes = data);
    } catch (_) {
      if (mounted) setState(() => _error = 'Download failed. Close and try again.');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uri = Uri.parse(widget.item.videoUrl ?? widget.item.audioUrl!);
      final extension = uri.path.split('.').last.toLowerCase();
      final suffix = RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension)
          ? extension : widget.item.hasVideo ? 'mp4' : 'mp3';
      final title = widget.item.title.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim();
      final saved = await FilePicker.saveFile(
        fileName: '${title.isEmpty ? 'Quran-Life' : title}.$suffix',
        bytes: _bytes!,
        dialogTitle: 'Save media',
      );
      if (!mounted) {
        return;
      }
      if (saved == null) {
        setState(() => _saving = false);
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kIsWeb ? 'Download sent to your browser.' : 'Media file saved.'),
      ));
    } catch (_) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Could not save the file. Please try Save again.';
      });
    }
  }

  @override
  void dispose() {
    _download.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total != null && _total! > 0
        ? (_received / _total!).clamp(0.0, 1.0) : null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Download media'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null) Text(_error!),
          if (_bytes == null && _error == null) ...[
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 12),
            Text(progress == null
                ? '${(_received / 1048576).toStringAsFixed(1)} MB downloaded'
                : '${(progress * 100).toStringAsFixed(0)}% downloaded'),
          ],
          if (_bytes != null) const Text('Ready. Tap Save to choose where to keep the file.'),
          if (_saving) const Padding(
            padding: EdgeInsets.only(top: 12),
            child: CircularProgressIndicator(),
          ),
        ]),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(_bytes == null ? 'Cancel' : 'Close')),
          if (_bytes != null) FilledButton(onPressed: _saving ? null : _save,
            child: const Text('Save')),
        ],
      ),
    );
  }
}
