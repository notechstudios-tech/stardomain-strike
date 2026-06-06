import 'dart:ui' show Color;
import '../components/star_component.dart';

class StarAlliance {
  final int id;
  final List<StarComponent> stars;
  final Color color;
  late final String owner; // 'alliance_<id>'
  bool isAwakened;

  StarAlliance({
    required this.id,
    required this.stars,
    required this.color,
  }) : isAwakened = false {
    owner = 'alliance_$id';
  }
}
