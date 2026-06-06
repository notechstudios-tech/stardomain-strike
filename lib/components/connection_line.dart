import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

/// An arrow from the origin star to the destination star, so it's clear which
/// is which when sending ships.
class ConnectionLine extends Component {
  Vector2 from; // origin
  Vector2 to;   // destination (arrowhead points here)
  final Color color;

  ConnectionLine({
    required this.from,
    required this.to,
    this.color = const Color(0xFF66BB6A),
  });

  @override
  void render(Canvas canvas) {
    final f = from.toOffset();
    final t = to.toOffset();
    final dx = t.dx - f.dx, dy = t.dy - f.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;

    final ux = dx / len, uy = dy / len; // unit vector origin → destination
    final px = -uy, py = ux;            // perpendicular

    const head = 22.0; // arrowhead length
    const half = 12.0; // arrowhead half-width
    const gap  = 6.0;  // small gap before the destination centre

    final tip   = Offset(t.dx - ux * gap, t.dy - uy * gap);
    final base  = Offset(tip.dx - ux * head, tip.dy - uy * head);
    final left  = Offset(base.dx + px * half, base.dy + py * half);
    final right = Offset(base.dx - px * half, base.dy - py * half);

    // Shaft — stops at the arrowhead base so the head isn't doubled up.
    canvas.drawLine(
      f,
      base,
      Paint()
        ..color = color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke,
    );

    // Arrowhead.
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }
}
