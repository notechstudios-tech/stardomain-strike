import 'dart:convert';

class StarSave {
  final double x, y;
  final String size;    // 'light' | 'medium' | 'large'
  final String? iconKey; // non-null for home stars ('enemy_blue', 'enemy_red')
  final String? owner;
  final int ships, resources, defence;
  final String specialType;        // SpecialStarType.name
  final int    wormholeTargetIndex;   // -1 if not wormhole
  final bool   wormholeDiscovered;
  final int    allianceId;            // -1 if not in an alliance
  final bool   active;                // true once attacked / engaged in combat

  const StarSave({
    required this.x,
    required this.y,
    required this.size,
    this.iconKey,
    this.owner,
    required this.ships,
    required this.resources,
    required this.defence,
    this.specialType = 'none',
    this.wormholeTargetIndex = -1,
    this.wormholeDiscovered = false,
    this.allianceId = -1,
    this.active = false,
  });

  Map<String, dynamic> toJson() => {
    'x': x, 'y': y, 'size': size, 'iconKey': iconKey, 'owner': owner,
    'ships': ships, 'resources': resources, 'defence': defence,
    'specialType': specialType,
    'wormholeTargetIndex': wormholeTargetIndex,
    'wormholeDiscovered': wormholeDiscovered,
    'allianceId': allianceId,
    'active': active,
  };

  factory StarSave.fromJson(Map<String, dynamic> j) => StarSave(
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    size: j['size'] as String,
    iconKey: j['iconKey'] as String?,
    owner: j['owner'] as String?,
    ships: j['ships'] as int,
    resources: j['resources'] as int,
    defence: j['defence'] as int,
    specialType: j['specialType'] as String? ?? 'none',
    wormholeTargetIndex: j['wormholeTargetIndex'] as int? ?? -1,
    wormholeDiscovered: j['wormholeDiscovered'] as bool? ?? false,
    allianceId: j['allianceId'] as int? ?? -1,
    active: j['active'] as bool? ?? false,
  );
}

class AllianceSave {
  final int id;
  final int color;       // ARGB value
  final bool isAwakened;

  const AllianceSave({
    required this.id,
    required this.color,
    required this.isAwakened,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'color': color, 'isAwakened': isAwakened,
  };

  factory AllianceSave.fromJson(Map<String, dynamic> j) => AllianceSave(
    id: j['id'] as int,
    color: j['color'] as int,
    isAwakened: j['isAwakened'] as bool? ?? false,
  );
}

class FleetSave {
  final int originIndex, destIndex;
  final String owner;
  final int ships, turnsRemaining, totalTurns;

  const FleetSave({
    required this.originIndex,
    required this.destIndex,
    required this.owner,
    required this.ships,
    required this.turnsRemaining,
    required this.totalTurns,
  });

  Map<String, dynamic> toJson() => {
    'originIndex': originIndex,
    'destIndex': destIndex,
    'owner': owner,
    'ships': ships,
    'turnsRemaining': turnsRemaining,
    'totalTurns': totalTurns,
  };

  factory FleetSave.fromJson(Map<String, dynamic> j) => FleetSave(
    originIndex: j['originIndex'] as int,
    destIndex: j['destIndex'] as int,
    owner: j['owner'] as String,
    ships: j['ships'] as int,
    turnsRemaining: j['turnsRemaining'] as int,
    totalTurns: j['totalTurns'] as int,
  );
}

class GameSave {
  final int turn;
  final int seed;
  final List<StarSave> stars;
  final List<FleetSave> fleets;
  final List<String> technologies;
  final List<AllianceSave> alliances;

  const GameSave({
    required this.turn,
    required this.seed,
    required this.stars,
    required this.fleets,
    this.technologies = const [],
    this.alliances = const [],
  });

  String toJsonString() => jsonEncode({
    'turn': turn,
    'seed': seed,
    'stars': stars.map((s) => s.toJson()).toList(),
    'fleets': fleets.map((f) => f.toJson()).toList(),
    'technologies': technologies,
    'alliances': alliances.map((a) => a.toJson()).toList(),
  });

  factory GameSave.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return GameSave(
      turn: j['turn'] as int,
      seed: j['seed'] as int,
      stars: (j['stars'] as List)
          .map((e) => StarSave.fromJson(e as Map<String, dynamic>))
          .toList(),
      fleets: (j['fleets'] as List)
          .map((e) => FleetSave.fromJson(e as Map<String, dynamic>))
          .toList(),
      technologies: (j['technologies'] as List?)?.cast<String>() ?? [],
      alliances: (j['alliances'] as List?)
              ?.map((e) => AllianceSave.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
