import 'package:flutter/material.dart';

import '../../data/media_repository.dart';
import '../../models/audio/media_item.dart';
import '../../state/audio/media_audio_controller.dart';
import '../../widgets/audio/media_audio_player.dart';
import 'media_video_feed_screen.dart';
import 'media_video_screen.dart';

class AudioScreen extends StatelessWidget {
  final MediaAudioController audioController;

  const AudioScreen({super.key, required this.audioController});

  void _openSection(
    BuildContext context,
    String title,
    IconData icon,
    MediaItemType type,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioSectionScreen(
          title: title,
          icon: icon,
          type: type,
          audioController: audioController,
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
                    child: Icon(Icons.play_circle_outline),
                  ),
                  title: const Text(
                    'Video Feed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Swipe through Islamic videos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MediaVideoFeedScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
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
                  subtitle: const Text('Listen to duas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _openSection(
                      context,
                      'Duas',
                      Icons.favorite_outline,
                      MediaItemType.dua,
                    );
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
                      MediaItemType.sermon,
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
                    _openSection(
                      context,
                      'Recitations',
                      Icons.graphic_eq,
                      MediaItemType.recitation,
                    );
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

class AudioSectionScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final MediaItemType type;
  final MediaAudioController audioController;

  const AudioSectionScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.type,
    required this.audioController,
  });

  @override
  State<AudioSectionScreen> createState() => _AudioSectionScreenState();
}

class _AudioSectionScreenState extends State<AudioSectionScreen> {
  final MediaRepository _repository = MediaRepository();

  late Future<List<MediaItem>> _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _items = _repository.getItems(widget.type);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<MediaItem>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 52),
                          const SizedBox(height: 16),
                          const Text(
                            'Could not load content.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              setState(_load);
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? const <MediaItem>[];

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.55,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(widget.icon, size: 52),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No media has been published yet.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                                          widget.audioController.playItem(item);
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
                );
              },
            ),
          ),
          MediaAudioPlayer(controller: widget.audioController),
        ],
      ),
    );
  }
}
