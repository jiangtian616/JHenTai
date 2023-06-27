import 'dart:ui';

/// #7EFFDD => Color
Color? aRGBString2Color(String? string) {
  if (string == null || string.isEmpty) {
    return null;
  }
  return Color(int.parse('FF${string.replaceAll('#', '')}', radix: 16));
}

/// Color => #7EFFDD
String? color2aRGBString(Color? color) {
  if (color == null) {
    return null;
  }
  return '#' + color.value.toRadixString(16).substring(2);
}
