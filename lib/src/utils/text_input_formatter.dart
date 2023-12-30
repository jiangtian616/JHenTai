import 'package:flutter/services.dart';

class DoubleRangeTextInputFormatter extends TextInputFormatter {
  double? minValue;
  double? maxValue;

  DoubleRangeTextInputFormatter({this.minValue, this.maxValue}) : assert(minValue != null || maxValue != null);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || (minValue != null && minValue! < 0 && newValue.text == '-')) {
      return newValue;
    }

    double newNum = double.tryParse(newValue.text) ?? minValue ?? maxValue ?? -100;

    if (minValue != null && newNum < minValue!) {
      return oldValue;
    }
    if (maxValue != null && newNum > maxValue!) {
      return oldValue;
    }

    return newValue;
  }
}

class IntRangeTextInputFormatter extends TextInputFormatter {
  int? minValue;
  int? maxValue;

  IntRangeTextInputFormatter({this.minValue, this.maxValue}) : assert(minValue != null || maxValue != null);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || (minValue != null && minValue! < 0 && newValue.text == '-')) {
      return newValue;
    }

    int newNum = int.tryParse(newValue.text) ?? -100;

    if (minValue != null && newNum < minValue!) {
      return TextEditingValue(text: minValue.toString());
    }
    if (maxValue != null && newNum > maxValue!) {
      return TextEditingValue(text: maxValue.toString());
    }

    return newValue;
  }
}
