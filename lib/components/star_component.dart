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
    final phase = (config.x * 0.007 + config.y * 0.011) % 1.0;

    if (config.size == StarSize.light) {
      // Small stars: rapid opacity twinkle — scale change is invisible at this size
      final period = 0.3 + phase * 0.7; // 0.3–1.0 s, each star different
      add(OpacityEffect.by(
        -0.82,
        EffectController(
          duration: period,
          reverseDuration: period * 0.4, // quick flash back to bright
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ));
    } else {
      // Medium/Large stars: scale pulse, clearly visible at these sizes
      final period = 1.2 + phase * 1.3;
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
  }

  // Visual radius — used for rings, spacing, etc.
  double get radius {
    if (size.x == 0) return 24.0;
    return size.x * scale.x / 2;
  }

  // Tap radius — always at least 44 world units so small stars stay tappable.
  double get tapRadius => radius < 44.0 ? 44.0 : radius;
}
