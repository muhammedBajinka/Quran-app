import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../state/audio/media_audio_controller.dart';

class MediaAudioPlayer extends StatelessWidget {
  final MediaAudioController controller;

  const MediaAudioPlayer({super.key, required this.controller});

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final item = controller.currentItem;

        if (item == null) {
          return const SizedBox.shrink();
        }

        final player = controller.player;

        return Material(
          elevation: 12,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (item.speaker != null &&
                                item.speaker!.trim().isNotEmpty)
                              Text(
                                item.speaker!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 19,
                          tooltip: 'Close player',
                          onPressed: controller.close,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<Duration?>(
                    stream: player.durationStream,
                    builder: (context, durationSnapshot) {
                      final duration = durationSnapshot.data ?? Duration.zero;

                      return StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;

                          final durationMs = duration.inMilliseconds;
                          final positionMs = position.inMilliseconds;

                          final maxValue = durationMs > 0
                              ? durationMs.toDouble()
                              : 1.0;

                          final value = positionMs
                              .clamp(0, durationMs > 0 ? durationMs : 0)
                              .toDouble();

                          return Column(
                            children: [
                              Slider(
                                value: value,
                                max: maxValue,
                                onChanged: durationMs > 0
                                    ? (newValue) {
                                        controller.seek(
                                          Duration(
                                            milliseconds: newValue.round(),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: controller.repeatEnabled
                            ? 'Repeat on'
                            : 'Repeat off',
                        onPressed: controller.toggleRepeat,
                        icon: Icon(
                          Icons.repeat,
                          color: controller.repeatEnabled
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final playing = state?.playing ?? false;
                          final processingState = state?.processingState;

                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return const SizedBox(
                              width: 48,
                              height: 48,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            );
                          }

                          return IconButton(
                            iconSize: 38,
                            tooltip: playing ? 'Pause' : 'Play',
                            onPressed: playing
                                ? controller.pause
                                : controller.play,
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                            ),
                          );
                        },
                      ),
                      PopupMenuButton<double>(
                        tooltip: 'Playback speed',
                        initialValue: controller.speed,
                        onSelected: controller.setSpeed,
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 0.75, child: Text('0.75×')),
                          PopupMenuItem(value: 1.0, child: Text('1.0×')),
                          PopupMenuItem(value: 1.25, child: Text('1.25×')),
                          PopupMenuItem(value: 1.5, child: Text('1.5×')),
                          PopupMenuItem(value: 2.0, child: Text('2.0×')),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '${controller.speed}×',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
