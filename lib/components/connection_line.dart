import 'dart:ui';
import 'package:flame/components.dart';

class ConnectionLine extends Component {
  Vector2 from;
  Vector2 to;
  final Color color;

  ConnectionLine({
    required this.from,
    required this.to,
    this.color = const Color(0xFF66BB6A),
  });

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from.toOffset(), to.toOffset(), paint);
  }
}
