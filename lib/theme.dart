import 'package:flutter/material.dart';

/// Visual constants matched to the reference video.
class AppColors {
  static const gameBg = Color(0xFFE0E0E0);
  static const overlay = Color(0xE62F3043);
  static const textDark = Color(0xFF4A4E78);
  static const lavender = Color(0xFF8E90DA);
  static const lavenderDark = Color(0xFF7275C4);
  static const popupBg = Color(0xFFF1F1FD);
  static const popupBorder = Color(0xFFB7B5EE);
  static const teal = Color(0xFF2EC4A6);
  static const salmon = Color(0xFFF2A488);
  static const green = Color(0xFF22DA6E);
  static const greenDark = Color(0xFF12B257);
  static const blue = Color(0xFF14A9F2);
  static const blueDark = Color(0xFF0B86CE);
  static const grayBtn = Color(0xFFA3A3AB);
  static const grayBtnDark = Color(0xFF808089);
  static const red = Color(0xFFF2506B);
  static const bannerPurple = Color(0xFFB08CF3);
  static const bannerPurpleDark = Color(0xFF8A68DE);
  static const loadTop = Color(0xFFDFEAF4);
  static const loadBottom = Color(0xFFD7C5EA);
  static const barTrack = Color(0xFFA79CE0);
  static const barFill = Color(0xFF5ACBF7);
  static const shopBlue = Color(0xFF6C9FF3);
  static const shopBlueDark = Color(0xFF5585DD);
}

const kTitleFont = 'Lilita';
const kBodyFont = 'Baloo';

TextStyle titleStyle(double size, {Color color = Colors.white, List<Shadow>? shadows}) => TextStyle(
      fontFamily: kTitleFont,
      fontSize: size,
      color: color,
      height: 1.05,
      shadows: shadows,
    );

TextStyle bodyStyle(double size, {Color color = AppColors.textDark, double weight = 800}) => TextStyle(
      fontFamily: kBodyFont,
      fontSize: size,
      color: color,
      height: 1.15,
      fontWeight: FontWeight.w800,
      fontVariations: [FontVariation('wght', weight)],
    );

Color darken(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
}

Color lighten(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}
