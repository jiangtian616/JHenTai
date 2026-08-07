import 'package:flutter/material.dart';

/// Scrollable terminal-style log for PaddleOCR runtime/model downloads.
class PaddleCliOutput extends StatelessWidget {
  final List<String> lines;

  const PaddleCliOutput({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 160,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: SelectableText(
          lines.join('\n'),
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
