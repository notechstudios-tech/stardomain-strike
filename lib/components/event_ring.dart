import 'dart:ui';
import 'package:flame/components.dart';

class EventRing extends PositionComponent {
  final double radius;
  late final Paint _paint;

  EventRing({required Vector2 starPosition, required this.radius})
      : super(position: starPosition, anchor: Anchor.center) {
    _paint = Paint()
      ..color = const Color(0xFFFF80AB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, _paint);
  }
}

class WormholeRing extends PositionComponent {
  final double radius;
  late final Paint _paint;

  WormholeRing({required Vector2 starPosition, required this.radius})
      : super(position: starPosition, anchor: Anchor.center) {
    _paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, _paint);
  }
}
