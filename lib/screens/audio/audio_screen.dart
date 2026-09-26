import 'package:flutter/material.dart';

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  void _openSection(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioSectionScreen(
          title: title,
          icon: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Listen to dua audio',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _openSection(
                context,
                'Duas',
                Icons.favorite_outline,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Listen to sermons and khutbahs',
            ),
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
      ],
    );
  }
}

class AudioSectionScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const AudioSectionScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 52,
              ),
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
                'No audio has been added yet.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
