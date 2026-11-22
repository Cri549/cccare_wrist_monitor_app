import 'package:flutter/material.dart';

class TextSizeSettings {
  static const double minSize = 0.8;
  static const double maxSize = 1.6;

  static ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static void setTextScale(double value) {
    textScale.value = value.clamp(minSize, maxSize);
  }
}
