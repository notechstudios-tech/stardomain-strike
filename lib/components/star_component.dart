import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../models/star_config.dart';

class StarComponent extends SpriteComponent with TapCallbacks {
  final StarConfig config;
  bool isSelected = false;

  StarComponent({required this.config, required Sprite sprite})
      : super(
          sprite: sprite,
          anchor: Anchor.center,
        );

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = true;
  }

  double get radius => size.x / 2;

  @override
  bool containsPoint(Vector2 point) {
    final dx = point.x - position.x;
    final dy = point.y - position.y;
    return dx * dx + dy * dy <= radius * radius;
  }
}
