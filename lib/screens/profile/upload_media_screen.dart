import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/audio/media_item.dart';
import '../../data/media_repository.dart';
import '../../services/video_trim_service.dart';
import '../../widgets/creator_media_editor.dart';

import '../../services/creator_upload_queue.dart';

class UploadMediaScreen extends StatefulWidget {
  const UploadMediaScreen({super.key});

  @override
  State<UploadMediaScreen> createState() => _UploadMediaScreenState();
}

class _UploadMediaScreenState extends State<UploadMediaScreen> {
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
  int _step = 0;
  RangeValues _trimRange = const RangeValues(0, 1);

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
        _trimRange = const RangeValues(0, 1);
        _step = 2;
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

  Future<void> _queueUpload() async {
    if (_busy) return;
    final file = _selectedFile;
    var bytes = _selectedBytes;
    final mime = _mimeType;
    if (file == null || bytes == null || mime == null) {
      _showMessage('Choose a media file first.');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showMessage('Enter a title.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_mediaType == 'video' && _trimRange.end > _trimRange.start) {
        final trimmed = await trimVideoFile(
          sourcePath: file.path,
          startMs: _trimRange.start,
          endMs: _trimRange.end,
        );
        if (trimmed == null) {
          _showMessage(
            'Could not prepare the trimmed video. Try again on the Android app.',
          );
          return;
        }
        bytes = trimmed;
      }

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your upload is processing and should be ready in a few minutes.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _nextStep() {
    if (_step == 1 && _selectedFile == null) {
      _showMessage('Choose a media file first.');
      return;
    }
    setState(() => _step++);
  }

  void _previousStep() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _previousStep();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _previousStep,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(_stepTitle),
        ),
        body: SafeArea(child: _buildStep()),
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Create';
      case 1:
        return 'Choose media';
      case 2:
        return 'Edit media';
      case 3:
        return 'Choose category';
      default:
        return 'Post details';
    }
  }

  Widget _buildStep() {
    if (_step == 0) return _mediaTypeStep();
    if (_step == 1) return _fileStep();
    if (_step == 2) return _editorStep();
    if (_step == 3) return _categoryStep();
    return _detailsStep();
  }

  Widget _mediaTypeStep() {
    return _stepShell(
      title: 'What do you want to share?',
      child: Column(
        children: [
          _choiceTile(
            label: 'Video',
            icon: Icons.videocam_outlined,
            selected: _mediaType == 'video',
            onTap: () => _changeMediaType('video'),
          ),
          _choiceTile(
            label: 'Audio',
            icon: Icons.audiotrack_outlined,
            selected: _mediaType == 'audio',
            onTap: () => _changeMediaType('audio'),
          ),
        ],
      ),
      onNext: _nextStep,
    );
  }

  Widget _fileStep() {
    return _stepShell(
      title: _mediaType == 'video' ? 'Choose your video' : 'Choose your audio',
      child: OutlinedButton.icon(
        onPressed: _pickMedia,
        icon: const Icon(Icons.upload_file_outlined),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(_selectedFile?.name ?? 'Choose file'),
        ),
      ),
      onNext: _selectedFile == null ? null : _nextStep,
    );
  }

  Widget _categoryStep() {
    const categories = [
      ('recitation', 'Recitation', Icons.menu_book_outlined),
      ('dua', 'Dua', Icons.volunteer_activism_outlined),
      ('sermon', 'Sermon', Icons.mic_none_outlined),
      ('other', 'Other', Icons.more_horiz),
    ];
    return _stepShell(
      title: 'What type of content is this?',
      child: Column(
        children: [
          for (final item in categories)
            _choiceTile(
              label: item.$2,
              icon: item.$3,
              selected: _contentType == item.$1,
              onTap: () => setState(() => _contentType = item.$1),
            ),
        ],
      ),
      onNext: _nextStep,
    );
  }

  Widget _editorStep() {
    final bytes = _selectedBytes;
    final mime = _mimeType;
    if (bytes == null || mime == null) return _fileStep();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _mediaType == 'video' ? 'Edit your video' : 'Edit your audio',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Preview it and drag the handles to choose the part you want to post.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CreatorMediaEditor(
              bytes: bytes,
              mediaType: _mediaType,
              mimeType: mime,
              sourcePath: _selectedFile?.path,
              trim: _trimRange,
              onTrimChanged: (range) {
                if (mounted) setState(() => _trimRange = range);
              },
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickMedia,
            icon: const Icon(Icons.swap_horiz),
            label: Text(
              _mediaType == 'video' ? 'Choose another video' : 'Choose another audio',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _nextStep, child: const Text('Next')),
        ],
      ),
    );
  }

  Widget _detailsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        const Text(
          'Finish your post',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _titleController,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _speakerController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Speaker or reciter (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLength: 500,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _visibility,
          decoration: const InputDecoration(
            labelText: 'Who can see this?',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Everyone')),
            DropdownMenuItem(
              value: 'followers',
              child: Text('Followers only'),
            ),
            DropdownMenuItem(value: 'private', child: Text('Only me')),
          ],
          onChanged: _saveAsDraft
              ? null
              : (value) =>
                    setState(() => _visibility = value ?? _visibility),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Save as draft'),
          subtitle: const Text('Only you can see it until you post it.'),
          value: _saveAsDraft,
          onChanged: (value) => setState(() => _saveAsDraft = value),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _queueUpload,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }

  Widget _stepShell({
    required String title,
    String? subtitle,
    required Widget child,
    required VoidCallback? onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 24),
          child,
          const Spacer(),
          FilledButton(onPressed: onNext, child: const Text('Next')),
        ],
      ),
    );
  }

  Widget _choiceTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? const Color(0xFFE7F1EC) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? const Color(0xFF2E7D5B)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2E7D5B), size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2E7D5B),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditDraftScreen extends StatefulWidget {
  final MediaItem item;

  const EditDraftScreen({super.key, required this.item});

  @override
  State<EditDraftScreen> createState() => _EditDraftScreenState();
}

class _EditDraftScreenState extends State<EditDraftScreen> {
  final MediaRepository _repository = MediaRepository();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.item.title);
  late final TextEditingController _speakerController =
      TextEditingController(text: widget.item.speaker ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.item.description ?? '');
  late String _visibility =
      widget.item.visibility == 'private' ? 'public' : widget.item.visibility;
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool publish}) async {
    if (_busy || _titleController.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _repository.publishOwnDraft(
        widget.item.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        speaker: _speakerController.text.trim(),
        visibility: _visibility,
        publish: publish,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this draft.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit draft')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speakerController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Speaker or reciter',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(
              labelText: 'Who can see this after posting?',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Everyone')),
              DropdownMenuItem(
                value: 'followers',
                child: Text('Followers only'),
              ),
              DropdownMenuItem(value: 'private', child: Text('Only me')),
            ],
            onChanged: (value) =>
                setState(() => _visibility = value ?? _visibility),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _busy ? null : () => _save(publish: false),
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : () => _save(publish: true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}
