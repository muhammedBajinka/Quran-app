import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import '../../state/progress_state.dart';

class MemorizationRecordScreen extends StatefulWidget {
  final QuranSurah surah;
  final List<int> selectedAyahs;
  final MemorizationState memorizationState;
  final ProgressState progressState;

  const MemorizationRecordScreen({
    super.key,
    required this.surah,
    required this.selectedAyahs,
    required this.memorizationState,
    required this.progressState,
  });

  @override
  State<MemorizationRecordScreen> createState() =>
      _MemorizationRecordScreenState();
}

class _MemorizationRecordScreenState
    extends State<MemorizationRecordScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isSaving = false;


  DateTime? _recordingStartedAt;

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  String _ayahSummary() {
    final sorted = [...widget.selectedAyahs]..sort();

    if (sorted.isEmpty) {
      return 'No ayahs selected';
    }

    if (sorted.length == 1) {
      return 'Ayah ${sorted.first}';
    }

    final ranges = <String>[];

    var start = sorted.first;
    var previous = sorted.first;

    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];

      if (current == previous + 1) {
        previous = current;
        continue;
      }

      ranges.add(
        start == previous
            ? '$start'
            : '$start–$previous',
      );

      start = current;
      previous = current;
    }

    ranges.add(
      start == previous
          ? '$start'
          : '$start–$previous',
    );

    return ranges.join(', ');
  }

  Future<Directory> _recordingsDirectory() async {
    final appDirectory =
        await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${appDirectory.path}/quran_memorization_recordings',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isSaving) {
      return;
    }

    try {
      final hasPermission =
          await _recorder.hasPermission();

      if (!hasPermission) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required to record.',
            ),
          ),
        );

        return;
      }

      final directory =
          await _recordingsDirectory();

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final filePath =
          '${directory.path}/surah_${widget.surah.number}_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
        ),
        path: filePath,
      );

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start recording: $error',
          ),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final path = await _recorder.stop();

      final startedAt = _recordingStartedAt;

      final durationSeconds = startedAt == null
          ? 0
          : DateTime.now()
              .difference(startedAt)
              .inSeconds;

      if (path == null || path.isEmpty) {
        throw Exception(
          'The recording file was not created.',
        );
      }

      final recording = MemorizationRecording(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        surahNumber: widget.surah.number,
        ayahNumbers: List.unmodifiable(
          [...widget.selectedAyahs]..sort(),
        ),
        filePath: path,
        createdAt: DateTime.now(),
        durationSeconds: durationSeconds,
      );

      widget.memorizationState.addRecording(
        recording,
      );

      await widget.progressState.recordRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _isSaving = false;
        _recordingStartedAt = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording saved.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _isSaving = false;
        _recordingStartedAt = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save recording: $error',
          ),
        ),
      );
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      await _recorder.cancel();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isSaving = false;
        _recordingStartedAt = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording cancelled.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to cancel recording: $error',
          ),
        ),
      );
    }
  }

  Future<void> _playRecording(
    MemorizationRecording recording,
  ) async {
    try {
      final file = File(recording.filePath);

      if (!await file.exists()) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This recording file is no longer available.',
            ),
          ),
        );

        return;
      }

      await _player.setFilePath(
        recording.filePath,
      );

      await _player.play();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to play recording: $error',
          ),
        ),
      );
    }
  }

  Future<void> _deleteRecording(
    MemorizationRecording recording,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete recording?'),
          content: const Text(
            'This recording will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final file = File(recording.filePath);

      if (await file.exists()) {
        await file.delete();
      }

      widget.memorizationState.removeRecording(
        recording.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording deleted.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete recording: $error',
          ),
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recordings =
        widget.memorizationState.recordingsForSurah(
      widget.surah.number,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.surah.nameTransliteration,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _ayahSummary(),
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.selectedAyahs.length} ayahs',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _isRecording
                          ? Icons.mic
                          : Icons.mic_none,
                      size: 64,
                      color: _isRecording
                          ? Theme.of(context)
                              .colorScheme
                              .error
                          : Theme.of(context)
                              .colorScheme
                              .primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? 'Recording...'
                          : 'Ready to record',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording
                          ? 'Keep reciting. Tap Stop when you finish.'
                          : 'This creates one continuous recording for the selected ayahs.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_isRecording)
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _stopRecording,
                            icon: const Icon(
                              Icons.stop,
                            ),
                            label: const Text('Stop & Save'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : _cancelRecording,
                            child: const Text('Cancel'),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : _startRecording,
                        icon: const Icon(Icons.mic),
                        label: const Text('Start Recording'),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Saved recordings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (recordings.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No recordings yet.',
                  ),
                ),
              )
            else
              ...recordings.reversed.map(
                (recording) {
                  return Card(
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: ListTile(
                      leading: IconButton(
                        tooltip: 'Play recording',
                        icon: const Icon(
                          Icons.play_circle_fill,
                        ),
                        onPressed: () {
                          _playRecording(recording);
                        },
                      ),
                      title: Text(
                        _ayahNumbersLabel(
                          recording.ayahNumbers,
                        ),
                      ),
                      subtitle: Text(
                        '${_formatDuration(recording.durationSeconds)} · '
                        '${recording.createdAt.day}/'
                        '${recording.createdAt.month}/'
                        '${recording.createdAt.year}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete recording',
                        icon: const Icon(
                          Icons.delete_outline,
                        ),
                        onPressed: () {
                          _deleteRecording(recording);
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _ayahNumbersLabel(List<int> ayahs) {
    if (ayahs.isEmpty) {
      return 'No ayahs';
    }

    if (ayahs.length == 1) {
      return 'Ayah ${ayahs.first}';
    }

    final sorted = [...ayahs]..sort();

    return 'Ayahs ${sorted.first}–${sorted.last}';
  }
}
