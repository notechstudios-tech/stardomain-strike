import 'dart:ui';
import 'package:flame/components.dart';

class BattleWonMarker extends PositionComponent {
  final double radius;
  late final Paint _paint;

  BattleWonMarker({required Vector2 starPosition, required this.radius})
      : super(position: starPosition, anchor: Anchor.center) {
    _paint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, _paint);
  }
}

class BattleLostMarker extends PositionComponent {
  final double armLength;
  late final Paint _paint;

  BattleLostMarker({required Vector2 starPosition, required this.armLength})
      : super(position: starPosition, anchor: Anchor.center) {
    _paint = Paint()
      ..color = const Color(0xFFEF5350)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawLine(Offset(-armLength, -armLength), Offset(armLength, armLength), _paint);
    canvas.drawLine(Offset(armLength, -armLength), Offset(-armLength, armLength), _paint);
  }
}
