import 'package:flutter/material.dart';

import '../../models/quran_models.dart';
import '../../state/memorization_state.dart';
import 'memorization_quran_session_screen.dart';

class MemorizationRevisionScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MemorizationQuranSessionScreen(
      surah: surah,
      selectedAyahs: selectedAyahs,
      memorizationState: memorizationState,
      type: MemorizationSessionType.revision,
    );
  }
}
