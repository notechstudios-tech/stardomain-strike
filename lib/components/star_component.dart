import 'package:flame/components.dart';
import '../models/star_config.dart';

class StarComponent extends SpriteComponent {
  final StarConfig config;
  String? owner; // mutable so captures work
  int ships;
  int resources;
  int defence;

  StarComponent({required this.config, required Sprite sprite})
      : owner = config.owner,
        ships = config.ships,
        resources = config.resources,
        defence = config.defence,
        super(sprite: sprite, anchor: Anchor.center);

  double get radius {
    if (size.x == 0) return 24.0;
    return size.x * scale.x / 2;
  }
}
