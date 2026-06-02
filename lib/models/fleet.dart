import '../components/star_component.dart';

class Fleet {
  final String owner;
  final StarComponent origin;
  final StarComponent destination;
  int ships;
  int turnsRemaining;
  final int totalTurns;

  Fleet({
    required this.owner,
    required this.origin,
    required this.destination,
    required this.ships,
    required this.turnsRemaining,
  }) : totalTurns = turnsRemaining;
}
