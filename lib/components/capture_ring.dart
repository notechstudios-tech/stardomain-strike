import 'dart:ui' show Color, Canvas, Paint, PaintingStyle, Offset;
import 'package:flame/components.dart';

class CaptureRing extends PositionComponent {
  final Color color;
  final double ringRadius;

  CaptureRing({
    required this.color,
    required this.ringRadius,
    required Vector2 starPosition,
  }) : super(position: starPosition, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      ringRadius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }
}
