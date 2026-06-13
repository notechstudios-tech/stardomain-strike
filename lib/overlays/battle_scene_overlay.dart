import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';
import '../models/battle_log.dart';

/// Full-screen animated battle: attackers (left) vs defenders (right). Steps
/// through the recorded battle log with lasers, shields and explosions, then
/// shows VICTORY!/DEFEAT!. The whole battle is capped at ~5 seconds.
class BattleSceneOverlay extends StatefulWidget {
  final StardomainGame game;
  const BattleSceneOverlay({super.key, required this.game});

  @override
  State<BattleSceneOverlay> createState() => _BattleSceneOverlayState();
}

class _BattleSceneOverlayState extends State<BattleSceneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final Stopwatch _watch = Stopwatch();
  late final BattleLog _battle;
  late final int _totalSteps;
  late final double _stepMs;
  int _lastSoundedStep = -1;

  @override
  void initState() {
    super.initState();
    _battle = widget.game.currentEvent!.battle!;
    _totalSteps = _battle.steps.length;
    // Whole battle <= 5s; many ships => quick steps.
    _stepMs = _totalSteps == 0 ? 1.0 : math.min(700.0, 5000.0 / _totalSteps);
    _watch.start();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            if (!mounted) return;
            _maybeSound();
            setState(() {});
          })
          ..repeat();
  }

  // Fire a sound when the battle advances to a new step (game throttles spam).
  void _maybeSound() {
    if (_totalSteps == 0) return;
    final idx = (_watch.elapsedMilliseconds / _stepMs).floor();
    if (idx < _totalSteps && idx != _lastSoundedStep) {
      _lastSoundedStep = idx;
      widget.game.playBattleSfx(hit: _battle.steps[idx].hit);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _watch.elapsedMilliseconds.toDouble();
    final stepIndex = _totalSteps == 0 ? 0 : (elapsed / _stepMs).floor();
    final over = stepIndex >= _totalSteps;

    // Replay steps up to (not including) the current one to get live counts.
    final upto = stepIndex.clamp(0, _totalSteps);
    int atkLost = 0, defLost = 0;
    for (var i = 0; i < upto; i++) {
      final s = _battle.steps[i];
      if (s.hit) {
        if (s.firingSide == BattleSide.attacker) {
          defLost++;
        } else {
          atkLost++;
        }
      }
    }
    final atkAlive = (_battle.attackers - atkLost).clamp(0, _battle.attackers);
    final defAlive = (_battle.defenders - defLost).clamp(0, _battle.defenders);
    final step = over ? null : _battle.steps[stepIndex];
    final p = _totalSteps == 0
        ? 1.0
        : ((elapsed % _stepMs) / _stepMs).clamp(0.0, 1.0);

    final mq = MediaQuery.of(context).size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.game.advanceEvent, // tap anywhere to skip / continue
      child: Container(
        color: Colors.black54, // dim the map behind the framed battle
        child: Center(
          child: Container(
            width: mq.width * 0.88,
            height: mq.height * 0.80,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x66FFFFFF), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xAA000000), blurRadius: 24),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BattlePainter(
                        battle: _battle,
                        atkAlive: atkAlive,
                        defAlive: defAlive,
                        step: step,
                        stepIndex: stepIndex,
                        stepProgress: p,
                        t: elapsed / 1000.0,
                      ),
                    ),
                  ),
                  // Title / result banner
                  Positioned(
                    top: 18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        over
                            ? (_battle.playerWon ? 'VICTORY!' : 'DEFEAT!')
                            : 'BATTLE',
                        style: TextStyle(
                          color: over
                              ? (_battle.playerWon
                                    ? const Color(0xFF66BB6A)
                                    : const Color(0xFFEF5350))
                              : Colors.white,
                          fontSize: over ? 34 : 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          decoration: TextDecoration.none,
                          shadows: const [
                            Shadow(blurRadius: 12, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Perks under each team
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _perks(_battle.attackerPerks, _battle.attackerColor),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _perks(
                      _battle.defenderPerks,
                      _battle.defenderColor,
                      right: true,
                    ),
                  ),
                  const Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Tap to continue',
                        style: TextStyle(
                          color: Color(0x88FFFFFF),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _perks(List<String> perks, Color color, {bool right = false}) {
    if (perks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: perks
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                s,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BattlePainter extends CustomPainter {
  final BattleLog battle;
  final int atkAlive, defAlive, stepIndex;
  final BattleStep? step;
  final double stepProgress, t;

  static const int _maxDraw = 18;

  _BattlePainter({
    required this.battle,
    required this.atkAlive,
    required this.defAlive,
    required this.step,
    required this.stepIndex,
    required this.stepProgress,
    required this.t,
  });

  int _drawn(int alive, int initial) {
    if (alive <= 0) return 0;
    if (initial <= _maxDraw) return alive;
    return (_maxDraw * alive / initial).ceil().clamp(1, _maxDraw);
  }

  List<Offset> _layout(int n, double sideX, double centerY, double s) {
    if (n <= 0) return const [];
    final cols = n == 1 ? 1 : math.min(4, math.sqrt(n).ceil());
    final rows = (n / cols).ceil();
    final sx = s * 2.6, sy = s * 2.4;
    return List.generate(n, (i) {
      final col = i % cols, row = i ~/ cols;
      return Offset(
        sideX + (col - (cols - 1) / 2) * sx,
        centerY + (row - (rows - 1) / 2) * sy,
      );
    });
  }

  double _bob(int i, double s, double phase) =>
      math.sin(t * 3 + i * 0.7 + phase) * s * 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cy = h * 0.52;
    final atkX = w * 0.21, defX = w * 0.79;
    final maxCount = math.max(battle.attackers, battle.defenders).clamp(1, 999);
    // Ships are small fighters — one-fifth of the earlier size.
    final s = (360 / math.sqrt(maxCount.toDouble())).clamp(16.0, 58.0) * 0.2;
    // Keep weapon/impact effects readable even when ships are tiny.
    final fx = math.max(s, 12.0);

    final dAtk = _drawn(atkAlive, battle.attackers);
    final dDef = _drawn(defAlive, battle.defenders);
    final atkPos = _layout(dAtk, atkX, cy, s);
    final defPos = _layout(dDef, defX, cy, s);

    for (var i = 0; i < dAtk; i++) {
      _fighter(
        canvas,
        atkPos[i].translate(0, _bob(i, s, 0)),
        s,
        1,
        battle.attackerColor,
      );
    }
    for (var i = 0; i < dDef; i++) {
      _fighter(
        canvas,
        defPos[i].translate(0, _bob(i, s, 1.5)),
        s,
        -1,
        battle.defenderColor,
      );
    }

    // Current firing effect
    if (step != null && dAtk > 0 && dDef > 0) {
      final firingAtk = step!.firingSide == BattleSide.attacker;
      final srcPos = firingAtk ? atkPos : defPos;
      final tgtPos = firingAtk ? defPos : atkPos;
      final srcDir = firingAtk ? 1.0 : -1.0;
      final srcColor = firingAtk ? battle.attackerColor : battle.defenderColor;
      final tgtColor = firingAtk ? battle.defenderColor : battle.attackerColor;
      final srcIdx = stepIndex % srcPos.length;
      final tgtIdx = step!.hit
          ? tgtPos.length - 1
          : (stepIndex * 7 + 3) % tgtPos.length;
      final src = srcPos[srcIdx].translate(
        srcDir * s * 0.5,
        _bob(srcIdx, s, firingAtk ? 0 : 1.5),
      );
      final tgt = tgtPos[tgtIdx].translate(
        0,
        _bob(tgtIdx, s, firingAtk ? 1.5 : 0),
      );

      _laser(canvas, src, tgt, srcColor, stepProgress);
      if (step!.hit) {
        _explosion(canvas, tgt, fx, stepProgress);
      } else {
        _shield(canvas, tgt, fx, tgtColor, stepProgress);
      }
    }

    _count(
      canvas,
      '$atkAlive',
      Offset(atkX, cy - h * 0.32),
      battle.attackerColor,
    );
    _count(
      canvas,
      '$defAlive',
      Offset(defX, cy - h * 0.32),
      battle.defenderColor,
    );
  }

  void _fighter(Canvas canvas, Offset c, double s, double dir, Color color) {
    final flick = math.sin(t * 22 + c.dx * 0.5) * 0.5 + 0.5;
    final tailX = c.dx - dir * s * 0.4;
    final flame = Path()
      ..moveTo(tailX, c.dy - s * 0.16)
      ..lineTo(tailX - dir * (s * 0.28 + s * 0.3 * flick), c.dy)
      ..lineTo(tailX, c.dy + s * 0.16)
      ..close();
    canvas.drawPath(
      flame,
      Paint()..color = const Color(0xFFFF7043).withValues(alpha: 0.9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tailX, c.dy - s * 0.08)
        ..lineTo(tailX - dir * (s * 0.18 + s * 0.2 * flick), c.dy)
        ..lineTo(tailX, c.dy + s * 0.08)
        ..close(),
      Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9),
    );

    final body = Path()
      ..moveTo(c.dx + dir * s * 0.5, c.dy) // nose
      ..lineTo(c.dx - dir * s * 0.35, c.dy - s * 0.32)
      ..lineTo(c.dx - dir * s * 0.18, c.dy)
      ..lineTo(c.dx - dir * s * 0.35, c.dy + s * 0.32)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(c.dx + dir * s * 0.08, c.dy),
      s * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _laser(Canvas canvas, Offset a, Offset b, Color color, double p) {
    if (p > 0.7) return;
    final op = (1.0 - p / 0.7).clamp(0.25, 1.0);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: op * 0.3)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: op)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _explosion(Canvas canvas, Offset c, double s, double p) {
    if (p < 0.35) return;
    final pp = ((p - 0.35) / 0.65).clamp(0.0, 1.0);
    final r = s * 0.4 + s * 1.2 * pp;
    final op = 1.0 - pp;
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: op * 0.7),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFFFA726).withValues(alpha: op * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (var k = 0; k < 6; k++) {
      final ang = k * math.pi / 3 + stepIndex;
      final from = c + Offset(math.cos(ang), math.sin(ang)) * r * 0.5;
      final to = c + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = const Color(0xFFFFCC80).withValues(alpha: op * 0.8)
          ..strokeWidth = 2,
      );
    }
  }

  void _shield(Canvas canvas, Offset c, double s, Color color, double p) {
    if (p < 0.2) return;
    final pp = ((p - 0.2) / 0.8).clamp(0.0, 1.0);
    final op = (1.0 - pp) * 0.9;
    final r = s * 0.72;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: op * 0.18),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFF81D4FA).withValues(alpha: op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _count(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '×$text',
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BattlePainter old) => true;
}
