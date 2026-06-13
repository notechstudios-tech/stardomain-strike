import 'dart:ui' show Color;
import '../components/star_component.dart';
import 'battle_log.dart';

class GameEvent {
  final String title;
  final String detail;
  final Color accentColor;
  final StarComponent? star;
  final BattleLog? battle; // non-null → play an animated battle scene

  const GameEvent({
    required this.title,
    required this.detail,
    this.accentColor = const Color(0xFFFF80AB),
    this.star,
    this.battle,
  });
}
