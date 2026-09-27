import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';

class MemorizationRevisionScreen extends StatefulWidget {
  final QuranSurah surah;
  final List<int> selectedAyahs;
  final MemorizationState memorizationState;

  const MemorizationRevisionScreen({
    super.key,
    required this.surah,
    required this.selectedAyahs,
    required this.memorizationState,
  });

  @override
  State<MemorizationRevisionScreen> createState() =>
      _MemorizationRevisionScreenState();
}

class _MemorizationRevisionScreenState
    extends State<MemorizationRevisionScreen> {
  late final List<int> _ayahs;
  int _currentIndex = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _ayahs = [...widget.selectedAyahs]..sort();
  }

  void _next() {
    if (_currentIndex < _ayahs.length - 1) {
      setState(() {
        _currentIndex++;
      });
      return;
    }

    final session = RevisionSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      surahNumber: widget.surah.number,
      ayahNumbers: List.unmodifiable(_ayahs),
      createdAt: DateTime.now(),
    );

    widget.memorizationState.addRevisionSession(session);

    setState(() {
      _completed = true;
    });
  }

  void _previous() {
    if (_currentIndex == 0) return;

    setState(() {
      _currentIndex--;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ayahs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Revision')),
        body: const Center(
          child: Text('No ayahs selected.'),
        ),
      );
    }

    if (_completed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Revision complete'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 72,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Revision complete',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_ayahs.length} ayahs revised.',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentAyah = _ayahs[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revision'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                widget.surah.nameTransliteration,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ayah ${_currentIndex + 1} of ${_ayahs.length}',
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _ayahs.length,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Revise Ayah',
                            style: TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$currentAyah',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Recite this ayah and check your memory.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _currentIndex == 0 ? null : _previous,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        _currentIndex == _ayahs.length - 1
                            ? 'Finish'
                            : 'Next',
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
  }
}
