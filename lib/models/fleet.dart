import '../components/star_component.dart';

class Fleet {
  final String owner;
  final StarComponent origin;
  final StarComponent destination;
  int ships;
  int turnsRemaining;

  Fleet({
    required this.owner,
    required this.origin,
    required this.destination,
    required this.ships,
    required this.turnsRemaining,
  });
}
