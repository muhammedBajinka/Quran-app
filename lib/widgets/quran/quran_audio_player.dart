import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class QuranAudioPlayer extends StatefulWidget {
  final String? audioUrl;

  const QuranAudioPlayer({super.key, required this.audioUrl});

  @override
  State<QuranAudioPlayer> createState() => _QuranAudioPlayerState();
}

class _QuranAudioPlayerState extends State<QuranAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  int _speedIndex = 2;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) {
      setState(() {
        _error = 'Audio is not available for this Surah yet.';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      if (_player.playing) {
        await _player.pause();
        return;
      }

      setState(() {
        _loading = true;
      });

      if (_player.audioSource == null) {
        await _player.setUrl(widget.audioUrl!);
        await _player.setSpeed(_speeds[_speedIndex]);
      }

      await _player.play();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to play this audio.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeSpeed() async {
    final nextIndex = (_speedIndex + 1) % _speeds.length;

    setState(() {
      _speedIndex = nextIndex;
    });

    await _player.setSpeed(_speeds[nextIndex]);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;

            final safePosition = position > duration ? duration : position;

            return StreamBuilder<bool>(
              stream: _player.playingStream,
              initialData: false,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;

                return Card(
                  margin: const EdgeInsets.only(top: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // ONE play/pause button.
                            IconButton(
                              iconSize: 34,
                              onPressed: _loading ? null : _togglePlayback,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                    ),
                            ),

                            const SizedBox(width: 8),

                            Text(
                              _formatDuration(safePosition),
                              style: const TextStyle(fontSize: 13),
                            ),

                            Expanded(
                              child: Slider(
                                min: 0,
                                max: duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1,
                                value: duration.inMilliseconds > 0
                                    ? safePosition.inMilliseconds.toDouble()
                                    : 0,
                                onChanged: duration.inMilliseconds > 0
                                    ? (value) {
                                        _player.seek(
                                          Duration(milliseconds: value.round()),
                                        );
                                      }
                                    : null,
                              ),
                            ),

                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(fontSize: 13),
                            ),

                            const SizedBox(width: 8),

                            // ONE speed button.
                            TextButton(
                              onPressed: _changeSpeed,
                              child: Text(
                                '${_speeds[_speedIndex].toStringAsFixed(_speeds[_speedIndex] == 1.0 ? 0 : 2)}×',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_error != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
