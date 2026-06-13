import 'dart:ui' show Color;

enum BattleSide { attacker, defender }

/// One firing action in a battle: who fired and whether it destroyed an enemy
/// ship (hit) or was absorbed by a shield (miss).
class BattleStep {
  final BattleSide firingSide;
  final bool hit;
  const BattleStep(this.firingSide, this.hit);
}

/// Everything the animated battle scene needs to replay a fight. Attacker is
/// drawn on the left, defender on the right.
class BattleLog {
  final int attackers; // ships shown on the attacking (left) side
  final int defenders; // ships shown on the defending (right) side
  final Color attackerColor;
  final Color defenderColor;
  final List<BattleStep> steps;
  final bool playerWon; // player-perspective outcome → VICTORY / DEFEAT
  final List<String> attackerPerks; // enhancement labels under the left team
  final List<String> defenderPerks; // enhancement labels under the right team

  const BattleLog({
    required this.attackers,
    required this.defenders,
    required this.attackerColor,
    required this.defenderColor,
    required this.steps,
    required this.playerWon,
    this.attackerPerks = const [],
    this.defenderPerks = const [],
  });
}
