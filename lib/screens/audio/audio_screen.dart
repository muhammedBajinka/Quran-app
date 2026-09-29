import 'package:flutter/material.dart';

import '../../models/audio/media_item.dart';
import '../../state/audio/media_audio_controller.dart';
import '../../widgets/audio/media_audio_player.dart';
import 'media_video_screen.dart';

class AudioScreen extends StatelessWidget {
  final MediaAudioController audioController;

  const AudioScreen({super.key, required this.audioController});

  void _openSection(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioSectionScreen(
          title: title,
          icon: icon,
          audioController: audioController,
          items: const <MediaItem>[],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const CircleAvatar(
                    child: Icon(Icons.favorite_outline),
                  ),
                  title: const Text(
                    'Duas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Listen to dua audio'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _openSection(context, 'Duas', Icons.favorite_outline);
                  },
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const CircleAvatar(
                    child: Icon(Icons.record_voice_over_outlined),
                  ),
                  title: const Text(
                    'Sermons',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Listen to sermons and khutbahs'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _openSection(
                      context,
                      'Sermons',
                      Icons.record_voice_over_outlined,
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const CircleAvatar(child: Icon(Icons.graphic_eq)),
                  title: const Text(
                    'Recitations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Listen to selected Quran recitations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _openSection(context, 'Recitations', Icons.graphic_eq);
                  },
                ),
              ),
            ],
          ),
        ),
        MediaAudioPlayer(controller: audioController),
      ],
    );
  }
}

class AudioSectionScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final MediaAudioController audioController;
  final List<MediaItem> items;

  const AudioSectionScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.audioController,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 52),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No media has been added yet.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.speaker != null &&
                                  item.speaker!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(item.speaker!),
                              ],
                              if (item.description != null &&
                                  item.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.description!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (item.hasAudio || item.hasVideo) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (item.hasAudio)
                                      FilledButton.icon(
                                        onPressed: () {
                                          audioController.playItem(item);
                                        },
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Listen'),
                                      ),
                                    if (item.hasVideo)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  MediaVideoScreen(item: item),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.play_circle_outline,
                                        ),
                                        label: const Text('Watch'),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          MediaAudioPlayer(controller: audioController),
        ],
      ),
    );
  }
}
