enum StarSize { light, medium, large }

enum SpecialStarType { none, friendlyEncounter, ancientTrap, wormhole, ancientRuins }

class StarConfig {
  final StarSize size;
  final double x;
  final double y;
  final String? owner; // null = unclaimed, 'player', 'enemy_red', 'enemy_blue'
  final int ships;
  final int resources;
  final int defence;

  const StarConfig({
    required this.size,
    required this.x,
    required this.y,
    this.owner,
    this.ships = 0,
    this.resources = 0,
    this.defence = 0,
  });
}
