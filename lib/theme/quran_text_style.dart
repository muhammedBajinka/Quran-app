import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Permanent typography for Arabic Quran text.
///
/// Quran editions, reciters, audio sources, and user settings must not
/// replace this typography.
abstract final class QuranTextStyle {
  static TextStyle arabic({
    double? fontSize,
    double? height,
    Color? color,
    Color? backgroundColor,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.amiriQuran(
      fontSize: fontSize,
      height: height,
      color: color,
      backgroundColor: backgroundColor,
      fontWeight: fontWeight,
    );
  }
}
