import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import '../models/fleet.dart';

class FleetMarker extends PositionComponent {
  final Fleet fleet;
  bool isSelected = false;

  static const double _r = 10.0;

  static final _playerFill   = Paint()..color = const Color(0xFF66BB6A)..style = ui.PaintingStyle.fill;
  static final _enemyFill    = Paint()..color = const Color(0xFFEF5350)..style = ui.PaintingStyle.fill;
  static final _outline      = Paint()..color = const Color(0xBBFFFFFF)..style = ui.PaintingStyle.stroke..strokeWidth = 1.5;
  static final _textPaint    = TextPaint(style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold));

  FleetMarker({required this.fleet})
      : super(size: Vector2.all(_r * 2), anchor: Anchor.center);

  void updatePosition() {
    if (fleet.totalTurns <= 0) return;
    final progress = 1.0 - fleet.turnsRemaining / fleet.totalTurns;
    position = fleet.origin.position +
        (fleet.destination.position - fleet.origin.position) * progress;
  }

  double get radius => _r;

  @override
  void render(Canvas canvas) {
    final fill = fleet.owner == 'player' ? _playerFill : _enemyFill;
    final selColor = fleet.owner == 'player' ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    canvas.drawCircle(Offset.zero, _r, fill);
    canvas.drawCircle(Offset.zero, _r, _outline);

    if (isSelected) {
      final sq = _r * 2.8;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: sq, height: sq),
        Paint()..color = selColor..style = ui.PaintingStyle.stroke..strokeWidth = 2.0,
      );
      _textPaint.render(
        canvas,
        '${fleet.ships}',
        Vector2(0, -_r - 4),
        anchor: Anchor.bottomCenter,
      );
    }
  }
}
