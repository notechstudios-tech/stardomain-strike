enum StarSize { light, medium, large }

class StarConfig {
  final StarSize size;
  final double x;
  final double y;
  final String? owner; // null = unclaimed, 'player', 'enemy_red', 'enemy_blue', etc.

  const StarConfig({
    required this.size,
    required this.x,
    required this.y,
    this.owner,
  });
}
