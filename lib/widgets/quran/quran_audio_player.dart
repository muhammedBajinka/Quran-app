import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/audio/quran_reciter.dart';
import '../../state/audio/quran_audio_controller.dart';

class QuranAudioPlayer extends StatefulWidget {
  final QuranAudioController controller;
  final List<QuranReciter> reciters;
  final ValueChanged<QuranReciter>? onReciterSelected;

  const QuranAudioPlayer({
    super.key,
    required this.controller,
    this.reciters = const [],
    this.onReciterSelected,
  });

  @override
  State<QuranAudioPlayer> createState() => _QuranAudioPlayerState();
}

class _QuranAudioPlayerState extends State<QuranAudioPlayer> {
  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  int _speedIndex = 2;
  bool _loading = false;
  bool _repeat = false;
  String? _error;

  AudioPlayer get _player => widget.controller.player;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen(_handlePlayerState);
  }

  void _handlePlayerState(PlayerState state) {
    if (!mounted) return;

    if (state.processingState == ProcessingState.completed && _repeat) {
      _player.seek(Duration.zero);
      _player.play();
    }
  }

  Future<void> _togglePlayback() async {
    final audioUrl = widget.controller.audioUrl;

    if (audioUrl == null || audioUrl.isEmpty) {
      setState(() {
        _error = 'Audio is not available for this Surah yet.';
      });
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (_player.playing) {
        await widget.controller.pause();
        return;
      }

      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }

      await widget.controller.play();
      await _player.setSpeed(_speeds[_speedIndex]);
    } catch (_) {
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

  void _toggleRepeat() {
    setState(() {
      _repeat = !_repeat;
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _speedLabel(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toInt()}×';
    }

    return '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')}×';
  }

  Future<void> _showReciters() async {
    if (widget.reciters.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<QuranReciter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.55;

        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Text(
                    'Choose Reciter',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.reciters.length,
                    itemBuilder: (context, index) {
                      final reciter = widget.reciters[index];
                      final isSelected =
                          widget.controller.selectedReciter?.id == reciter.id;

                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(reciter.name),
                        onTap: () {
                          Navigator.of(context).pop(reciter);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    widget.controller.setReciter(selected);
    widget.onReciterSelected?.call(selected);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.reciters.isEmpty ? null : _showReciters,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over_outlined, size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.controller.selectedReciter?.name ??
                              'Choose Reciter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (widget.reciters.isNotEmpty)
                        const Icon(Icons.keyboard_arrow_up),
                    ],
                  ),
                ),
              ),
              StreamBuilder<Duration?>(
                stream: _player.durationStream,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;

                  return StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;

                      final safePosition = position > duration
                          ? duration
                          : position;

                      return Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              _formatDuration(safePosition),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1,
                              value: duration.inMilliseconds > 0
                                  ? safePosition.inMilliseconds
                                        .clamp(0, duration.inMilliseconds)
                                        .toDouble()
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
                          SizedBox(
                            width: 48,
                            child: Text(
                              _formatDuration(duration),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: _repeat ? 'Turn repeat off' : 'Repeat Surah',
                    onPressed: _toggleRepeat,
                    icon: Icon(
                      Icons.repeat,
                      color: _repeat
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(width: 26),
                  StreamBuilder<bool>(
                    stream: _player.playingStream,
                    initialData: _player.playing,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;

                      return IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        iconSize: 42,
                        onPressed: _loading ? null : _togglePlayback,
                        icon: _loading
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: 26),
                  TextButton(
                    onPressed: _changeSpeed,
                    child: Text(
                      _speedLabel(_speeds[_speedIndex]),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
