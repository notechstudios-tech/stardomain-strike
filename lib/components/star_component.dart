import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Each star gets a slightly different period so they shimmer out of sync
    final period = 1.2 + (config.x * 0.007 + config.y * 0.011) % 1.3;
    add(ScaleEffect.by(
      Vector2.all(1.15),
      EffectController(
        duration: period,
        reverseDuration: period,
        infinite: true,
        curve: Curves.easeInOut,
      ),
    ));
  }

  // Visual radius — used for rings, spacing, etc.
  double get radius {
    if (size.x == 0) return 24.0;
    return size.x * scale.x / 2;
  }

  // Tap radius — always at least 44 world units so small stars stay tappable.
  // Larger stars grow naturally beyond this floor.
  double get tapRadius => radius < 44.0 ? 44.0 : radius;
}
