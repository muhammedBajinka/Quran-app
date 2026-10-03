import 'package:flutter/material.dart';

/// Permanent typography for Arabic Quran text.
///
/// Quran editions, reciters, audio sources, and user settings must not
/// replace this font family. Only properties such as size, colour, and
/// highlighting should vary.
abstract final class QuranTextStyle {
  static const String fontFamily = 'NotoNaskhArabic';

  static TextStyle arabic({
    double? fontSize,
    double? height,
    Color? color,
    Color? backgroundColor,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: height,
      color: color,
      backgroundColor: backgroundColor,
      fontWeight: fontWeight,
    );
  }
}
