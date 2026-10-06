import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/creator_upload_queue.dart';

class UploadMediaScreen extends StatefulWidget {
  const UploadMediaScreen({super.key});

  @override
  State<UploadMediaScreen> createState() => _UploadMediaScreenState();
}

class _UploadMediaScreenState extends State<UploadMediaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  final _descriptionController = TextEditingController();

  PlatformFile? _selectedFile;
  Uint8List? _selectedBytes;
  String? _mimeType;

  Uint8List? _thumbnailBytes;
  String? _thumbnailMimeType;
  String? _thumbnailName;

  String _mediaType = 'audio';
  String _contentType = 'recitation';
  String _visibility = 'public';
  bool _saveAsDraft = false;
  bool _busy = false;

  static const _audioMimeTypes = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'webm': 'audio/webm',
  };
  static const _videoMimeTypes = {
    'mp4': 'video/mp4',
    'webm': 'video/webm',
  };
  static const _imageMimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<String> get _allowedExtensions =>
      (_mediaType == 'audio' ? _audioMimeTypes : _videoMimeTypes)
          .keys
          .toList();

  String? _mediaMime(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    if (extension == null) return null;
    return (_mediaType == 'audio' ? _audioMimeTypes : _videoMimeTypes)[extension];
  }

  Future<void> _pickMedia() async {
    if (_busy) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (files.isEmpty) return;
      final file = files.single;
      final mime = _mediaMime(file);
      if (mime == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedFile = file;
        _selectedBytes = bytes;
        _mimeType = mime;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the media picker.')),
      );
    }
  }

  Future<void> _pickThumbnail() async {
    if (_busy) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _imageMimeTypes.keys.toList(),
      );
      if (files.isEmpty) return;
      final file = files.single;
      final mime = _imageMimeTypes[file.extension?.toLowerCase()];
      if (mime == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _thumbnailBytes = bytes;
        _thumbnailMimeType = mime;
        _thumbnailName = file.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the image picker.')),
      );
    }
  }

  void _changeMediaType(String type) {
    if (_busy || type == _mediaType) return;
    setState(() {
      _mediaType = type;
      _selectedFile = null;
      _selectedBytes = null;
      _mimeType = null;
    });
  }

  void _queueUpload() {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final file = _selectedFile;
    final bytes = _selectedBytes;
    final mime = _mimeType;

    if (file == null || bytes == null || mime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a media file first.')),
      );
      return;
    }

    setState(() => _busy = true);

    CreatorUploadQueue.instance.enqueue(
      CreatorUploadJob(
        localId: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: file.name,
        bytes: bytes,
        mimeType: mime,
        contentType: _contentType,
        mediaType: _mediaType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        speaker: _speakerController.text.trim(),
        visibility: _visibility,
        draft: _saveAsDraft,
        thumbnailBytes: _thumbnailBytes,
        thumbnailMimeType: _thumbnailMimeType,
      ),
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New upload')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'audio', label: Text('Audio'), icon: Icon(Icons.audiotrack)),
                ButtonSegment(value: 'video', label: Text('Video'), icon: Icon(Icons.videocam_outlined)),
              ],
              selected: {_mediaType},
              onSelectionChanged: (value) => _changeMediaType(value.first),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_selectedFile?.name ?? 'Choose media file'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickThumbnail,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _thumbnailName == null
                    ? 'Choose cover image'
                    : 'Cover: $_thumbnailName',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'The cover is what people see on your profile before opening the media.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _contentType,
              decoration: const InputDecoration(labelText: 'Content type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'recitation', child: Text('Recitation')),
                DropdownMenuItem(value: 'dua', child: Text('Dua')),
                DropdownMenuItem(value: 'sermon', child: Text('Sermon')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _contentType = value ?? _contentType),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              maxLength: 120,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a title.' : null,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _speakerController,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Speaker or reciter (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Who can see this?', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Everyone')),
                DropdownMenuItem(value: 'followers', child: Text('Followers only')),
                DropdownMenuItem(value: 'private', child: Text('Only me')),
              ],
              onChanged: _saveAsDraft
                  ? null
                  : (value) => setState(() => _visibility = value ?? _visibility),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save as draft'),
              subtitle: const Text('Upload it now, but do not publish it yet. Only you can see drafts.'),
              value: _saveAsDraft,
              onChanged: (value) => setState(() => _saveAsDraft = value),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy ? null : _queueUpload,
              icon: const Icon(Icons.add_to_queue_rounded),
              label: Text(_saveAsDraft ? 'Add draft to queue' : 'Add to upload queue'),
            ),
          ],
        ),
      ),
    );
  }
}
