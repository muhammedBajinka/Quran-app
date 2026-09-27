import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import 'memorization_ayah_actions_screen.dart';

class MemorizationAyahSelectionScreen extends StatefulWidget {
  final QuranSurah surah;
  final MemorizationState memorizationState;

  const MemorizationAyahSelectionScreen({
    super.key,
    required this.surah,
    required this.memorizationState,
  });

  @override
  State<MemorizationAyahSelectionScreen> createState() =>
      _MemorizationAyahSelectionScreenState();
}

class _MemorizationAyahSelectionScreenState
    extends State<MemorizationAyahSelectionScreen> {
  final Set<int> _selectedAyahs = {};

  @override
  void initState() {
    super.initState();

    _selectedAyahs.addAll(
      widget.memorizationState.memorizedAyahsForSurah(
        widget.surah.number,
      ),
    );
  }

  void _selectAll() {
    setState(() {
      if (_selectedAyahs.length == widget.surah.ayahCount) {
        _selectedAyahs.clear();
      } else {
        _selectedAyahs
          ..clear()
          ..addAll(
            List<int>.generate(
              widget.surah.ayahCount,
              (index) => index + 1,
            ),
          );
      }
    });
  }

  void _toggleAyah(int ayahNumber) {
    setState(() {
      if (_selectedAyahs.contains(ayahNumber)) {
        _selectedAyahs.remove(ayahNumber);
      } else {
        _selectedAyahs.add(ayahNumber);
      }
    });
  }

  void _saveSelection() {
    if (_selectedAyahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one ayah.'),
        ),
      );
      return;
    }

    final selected = _selectedAyahs.toList()..sort();

    widget.memorizationState.setAyahsMemorized(
      widget.surah.number,
      selected,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MemorizationAyahActionsScreen(
          surah: widget.surah,
          selectedAyahs: selected,
          memorizationState: widget.memorizationState,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _selectedAyahs.length == widget.surah.ayahCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.surah.nameTransliteration),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.surah.nameArabic,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.surah.ayahCount} ayahs',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _selectAll,
                      icon: Icon(
                        allSelected
                            ? Icons.deselect
                            : Icons.select_all,
                      ),
                      label: Text(
                        allSelected ? 'Deselect all' : 'Select all',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: widget.surah.ayahCount,
                itemBuilder: (context, index) {
                  final ayahNumber = index + 1;
                  final selected =
                      _selectedAyahs.contains(ayahNumber);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _toggleAyah(ayahNumber),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outline,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$ayahNumber',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedAyahs.length} selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _saveSelection,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
