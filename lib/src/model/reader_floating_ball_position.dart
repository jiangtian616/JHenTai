import 'dart:math' as math;

/// Normalized position of the reader's floating translation ball.
///
/// Normalizing against the safe content area means a phone/tablet can rotate
/// or change size without restoring a pixel offset outside the viewport.
class ReaderFloatingBallPosition {
  const ReaderFloatingBallPosition({required this.x, required this.y});

  final double x;
  final double y;

  ReaderFloatingBallPosition clamp() => ReaderFloatingBallPosition(
    x: x.clamp(0, 1).toDouble(),
    y: y.clamp(0, 1).toDouble(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{'x': x, 'y': y};

  factory ReaderFloatingBallPosition.fromJson(Map<String, dynamic> json) =>
      ReaderFloatingBallPosition(
        x: (json['x'] as num?)?.toDouble() ?? 1,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
      ).clamp();

  @override
  bool operator ==(Object other) =>
      other is ReaderFloatingBallPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
