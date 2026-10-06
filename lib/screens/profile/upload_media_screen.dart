import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/media_worker_service.dart';

class UploadMediaScreen extends StatefulWidget {
  const UploadMediaScreen({super.key});

  @override
  State<UploadMediaScreen> createState() => _UploadMediaScreenState();
}

class _UploadMediaScreenState extends State<UploadMediaScreen> {
  final MediaWorkerService _mediaWorkerService = MediaWorkerService();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  final _descriptionController = TextEditingController();

  PlatformFile? _selectedFile;
  Uint8List? _selectedBytes;
  String? _mimeType;

  String _mediaType = 'audio';
  String _contentType = 'recitation';
  bool _uploading = false;

  static const Map<String, String> _audioMimeTypes = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'webm': 'audio/webm',
  };

  static const Map<String, String> _videoMimeTypes = {
    'mp4': 'video/mp4',
    'webm': 'video/webm',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<String> get _allowedExtensions {
    return _mediaType == 'audio'
        ? _audioMimeTypes.keys.toList()
        : _videoMimeTypes.keys.toList();
  }

  String? _mimeTypeForFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase();

    if (extension == null) {
      return null;
    }

    if (_mediaType == 'audio') {
      return _audioMimeTypes[extension];
    }

    return _videoMimeTypes[extension];
  }

  void _changeMediaType(String mediaType) {
    if (_uploading || mediaType == _mediaType) {
      return;
    }

    setState(() {
      _mediaType = mediaType;
      _selectedFile = null;
      _selectedBytes = null;
      _mimeType = null;
    });
  }

  Future<void> _pickFile() async {
    if (_uploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      final mimeType = _mimeTypeForFile(file);

      if (bytes == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file.')),
        );
        return;
      }

      if (mimeType == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mediaType == 'audio'
                  ? 'Choose an MP3, M4A, or WebM audio file.'
                  : 'Choose an MP4 or WebM video file.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _selectedFile = file;
        _selectedBytes = bytes;
        _mimeType = mimeType;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the file picker. Please try again.'),
        ),
      );
    }
  }

  Future<void> _upload() async {
    if (_uploading) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final file = _selectedFile;
    final bytes = _selectedBytes;
    final mimeType = _mimeType;

    if (file == null || bytes == null || mimeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a media file before uploading.')),
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      await _mediaWorkerService.uploadMedia(
        bytes: bytes,
        mimeType: mimeType,
        contentType: _contentType,
        mediaType: _mediaType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        speaker: _speakerController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media uploaded successfully.')),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kilobytes = bytes / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final selectedFile = _selectedFile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Upload media',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            const Text(
              'Media type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'audio',
                  icon: Icon(Icons.audiotrack_rounded),
                  label: Text('Audio'),
                ),
                ButtonSegment<String>(
                  value: 'video',
                  icon: Icon(Icons.videocam_outlined),
                  label: Text('Video'),
                ),
              ],
              selected: {_mediaType},
              onSelectionChanged: _uploading
                  ? null
                  : (selection) {
                      _changeMediaType(selection.first);
                    },
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _uploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFB8C5BE)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: selectedFile == null
                    ? Column(
                        children: [
                          Icon(
                            _mediaType == 'audio'
                                ? Icons.audio_file_outlined
                                : Icons.video_file_outlined,
                            size: 42,
                            color: const Color(0xFF2E7D5B),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _mediaType == 'audio'
                                ? 'Choose audio file'
                                : 'Choose video file',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _mediaType == 'audio'
                                ? 'MP3, M4A or WebM'
                                : 'MP4 or WebM',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            _mediaType == 'audio'
                                ? Icons.audiotrack_rounded
                                : Icons.videocam_outlined,
                            color: const Color(0xFF2E7D5B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFile.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatFileSize(selectedFile.size),
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_outlined),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _contentType,
              decoration: const InputDecoration(
                labelText: 'Content type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'recitation',
                  child: Text('Recitation'),
                ),
                DropdownMenuItem(value: 'dua', child: Text('Dua')),
                DropdownMenuItem(value: 'sermon', child: Text('Sermon')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: _uploading
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _contentType = value;
                      });
                    },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleController,
              enabled: !_uploading,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a title.';
                }

                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Give your upload a title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _speakerController,
              enabled: !_uploading,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Speaker or reciter',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _descriptionController,
              enabled: !_uploading,
              maxLength: 500,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _uploading ? 'Uploading...' : 'Upload',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
