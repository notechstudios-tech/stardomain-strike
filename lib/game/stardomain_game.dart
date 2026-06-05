import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/battle_marker.dart';
import '../components/capture_ring.dart';
import '../components/connection_line.dart';
import '../components/event_ring.dart';
import '../components/fleet_marker.dart';
import '../components/star_component.dart';
import '../models/game_event.dart';
import '../models/technology.dart';
import '../models/fleet.dart';
import '../models/star_config.dart';
import '../models/game_save.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';

enum GameState { menu, playing, transitioning }

enum WinResult {
  playerElimination,   // player destroyed all enemy stars
  playerConquest,      // player controls 80% of stars
  playerDominance,     // player has ≥20 stars and 4× stars & ships → enemy surrenders
  enemyConquest,       // enemy controls 80% of stars
  playerDefeated,      // player has no stars left
  playerHomeBaseLost,  // enemy captured the player's home star
  enemyHomeBaseLost,   // player captured the enemy's home star
}

class StardomainGame extends FlameGame {
  static const String overlayMenu         = 'menu';
  static const String overlayMessage      = 'message';
  static const String overlayHud          = 'hud';
  static const String overlayStarInfo     = 'starInfo';
  static const String overlayAction       = 'action';
  static const String overlayBattleReport = 'battleReport';
  static const String overlayGameResult   = 'gameResult';
  static const String overlayEvent        = 'event';

  static const double universeWidth   = 3200;
  static const double universeHeight  = 1600;
  static const int    neutralStarCount = 160;
  static const double travelSpeed     = 400.0;

  static const double playerStarX = 800;
  static const double playerStarY = 800;
  static const double enemyStarX  = 2400;
  static const double enemyStarY  = 800;

  final AdsService adsService = AdsService();

  GameState _state          = GameState.menu;
  int       _currentTurn    = 1;
  int       _universeRngSeed = 0;

  // Cumulative battle statistics
  int battlesWon  = 0;
  int battlesLost = 0;
  int starsGained = 0;
  int starsLost   = 0;
  int shipsLost   = 0;

  final List<StarComponent>              _stars         = [];
  final List<Fleet>                      _fleets        = [];
  final Map<Fleet, FleetMarker>          _fleetMarkers  = {};
  final Map<StarComponent, CaptureRing>  _captureRings  = {};
  final List<PositionComponent>          _battleMarkers = [];
  final Map<StarComponent, WormholeRing> _wormholeRings = {};

  Completer<void>? _battleReportCompleter;

  WinResult? _gameResult;
  WinResult? get gameResult => _gameResult;

  StarComponent? _playerHomeBase;
  StarComponent? _enemyHomeBase;

  // Event queue for special star encounters and disasters
  final List<GameEvent>   _eventQueue = [];
  GameEvent?              _currentEvent;
  GameEvent?              get currentEvent => _currentEvent;
  PositionComponent?      _eventRingComponent;

  // Discovered technologies
  final Set<Technology> _playerTechs = {};
  bool hasTech(Technology t) => _playerTechs.contains(t);

  // Quantum-vision peek star (non-player star tapped with quantum vision)
  StarComponent? _peekedStar;
  StarComponent? get peekedStar      => _peekedStar;
  bool           get isPeekingAtStar => _selectedStar == null && _peekedStar != null;

  // Auto-move tracking
  final Set<StarComponent> _autoMovedStars = {};
  StarComponent?           _pendingAutoMoveStar;

  // Selection
  StarComponent?   _selectedStar;
  StarComponent?   _targetStar;
  SpriteComponent? _ring1;
  SpriteComponent? _ring2;
  ConnectionLine?  _connectionLine;
  int              _shipsToSend = 0;
  FleetMarker?     _selectedMarker;

  final Map<String, Sprite> _sprites = {};
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  String messageText = '';

  void Function(String)? onMessageChanged;
  void Function()?       onHudChanged;
  void Function()?       onActionChanged;
  void Function(StarComponent?)? onStarSelected;

  // ─── Public accessors ────────────────────────────────────────────────────

  int get currentTurn      => _currentTurn;
  int get totalPlayerShips => _stars.where((s) => s.owner == 'player' && s.isMounted).fold(0, (sum, s) => sum + s.ships);
  int get totalPlayerStars => _stars.where((s) => s.owner == 'player' && s.isMounted).length;

  StarComponent? get selectedStar => _selectedStar;
  StarComponent? get targetStar   => _targetStar;
  int get shipsToSend => _shipsToSend;

  int shipsInTransitFrom(StarComponent star) => _fleets
      .where((f) => f.origin == star && f.owner == 'player')
      .fold(0, (sum, f) => sum + f.ships);

  int get distanceInTurns {
    if (_selectedStar == null || _targetStar == null) return 0;
    final d = (_selectedStar!.position - _targetStar!.position).length;
    final speed = hasTech(Technology.improvedEngines) ? travelSpeed * 2 : travelSpeed;
    return math.max(1, (d / speed).ceil());
  }

  void increaseShips() {
    if (_selectedStar == null || _shipsToSend >= _selectedStar!.ships) return;
    _shipsToSend++;
    onActionChanged?.call();
  }

  void decreaseShips() {
    if (_shipsToSend <= 1) return;
    _shipsToSend--;
    onActionChanged?.call();
  }

  void sendFleet() {
    if (_selectedStar == null || _targetStar == null || _shipsToSend <= 0) return;
    if (_selectedStar!.ships < _shipsToSend) return;
    final origin = _selectedStar!;
    origin.ships -= _shipsToSend;
    final fleet = Fleet(
      owner: 'player',
      origin: origin,
      destination: _targetStar!,
      ships: _shipsToSend,
      turnsRemaining: distanceInTurns,
    );
    _fleets.add(fleet);
    _addFleetMarker(fleet);
    _sfx.play(AssetSource('sound/select.wav'));
    if (_pendingAutoMoveStar == origin) {
      _autoMovedStars.add(origin);
      _pendingAutoMoveStar = null;
    }
    _deselectAll();
    onHudChanged?.call();
  }

  void autoMove() {
    if (_state != GameState.playing) return;

    final candidates = _stars
        .where((s) => s.owner == 'player' && s.isMounted &&
            !_autoMovedStars.contains(s) && s.ships > 0)
        .toList()
      ..sort((a, b) => b.ships.compareTo(a.ships));

    if (candidates.isEmpty) return;
    final origin = candidates.first;

    final targets = _stars
        .where((s) => s.owner != 'player' && s.isMounted)
        .toList()
      ..sort((a, b) => (a.position - origin.position).length2
          .compareTo((b.position - origin.position).length2));

    if (targets.isEmpty) return;
    final target = targets.first;

    _deselectAll();
    _setFirstStar(origin);
    _setTargetStar(target);
    _zoomToShowStars(origin, target);
    _pendingAutoMoveStar = origin;
  }

  void warp() {
    if (_state != GameState.playing) return;
    final star = _selectedStar;
    if (star == null || star.specialType != SpecialStarType.wormhole) return;
    if (star.wormholeTarget == null || !star.wormholeTarget!.isMounted) return;
    if (_shipsToSend <= 0 || star.ships < _shipsToSend) return;

    final origin = star;
    origin.ships -= _shipsToSend;
    final fleet = Fleet(
      owner: 'player',
      origin: origin,
      destination: origin.wormholeTarget!,
      ships: _shipsToSend,
      turnsRemaining: 1,
      totalTurns: 1,
    );
    _fleets.add(fleet);
    _addFleetMarker(fleet);
    _sfx.play(AssetSource('sound/select.wav'));
    if (_pendingAutoMoveStar == origin) {
      _autoMovedStars.add(origin);
      _pendingAutoMoveStar = null;
    }
    _deselectAll();
    onHudChanged?.call();
  }

  void _zoomToShowStars(StarComponent a, StarComponent b) {
    const padding = 160.0;
    final midX  = (a.position.x + b.position.x) / 2;
    final midY  = (a.position.y + b.position.y) / 2;
    final spanW = (a.position.x - b.position.x).abs() + padding * 2;
    final spanH = (a.position.y - b.position.y).abs() + padding * 2;
    final newZoom = math.min(size.x / spanW, size.y / spanH).clamp(0.3, 3.0);
    camera.viewfinder.zoom = newZoom;
    camera.viewfinder.position = Vector2(
      midX - size.x / (2 * newZoom),
      midY - size.y / (2 * newZoom),
    );
    _clampCamera();
  }

  // ─── Turn processing ──────────────────────────────────────────────────────

  Future<void> endTurn() async {
    if (_state != GameState.playing) return;
    _state = GameState.transitioning;
    _deselectAll();

    // Clear previous turn's markers, stats, and auto-move state
    for (final m in _battleMarkers) { m.removeFromParent(); }
    _battleMarkers.clear();
    battlesWon = battlesLost = starsGained = starsLost = shipsLost = 0;
    _autoMovedStars.clear();
    _pendingAutoMoveStar = null;
    _eventQueue.clear();

    final rand = math.Random();

    // 0. Natural disasters (before battles)
    _applyNaturalDisasters(rand);

    // 1. Player fleets advance and battle (before any production)
    _advanceFleets('player', rand);

    // 2. Enemy AI sends ships
    _runEnemyAI(rand);

    // 3. Enemy fleets advance and battle
    _advanceFleets('enemy_red', rand);
    _advanceFleets('enemy_blue', rand);

    // 4. Production runs AFTER all battles so the player clearly sees
    //    the battle outcome before new ships are added.
    for (final s in _stars.where((s) => s.owner == 'player' && s.isMounted)) {
      s.ships += s.resources + (hasTech(Technology.improvedProduction) ? 1 : 0);
    }
    for (final s in _stars.where((s) => _isEnemy(s.owner) && s.isMounted)) {
      s.ships += s.resources;
    }

    // 5. Update all remaining fleet marker positions
    for (final m in _fleetMarkers.values) {
      if (m.isMounted) m.updatePosition();
    }

    _currentTurn++;

    // 6. Show queued events (special stars, disasters) — camera pans to each
    await _processEventQueue();
    if (_state == GameState.menu) return;

    // 7. Show battle report — user can pan/zoom to inspect markers on the map
    _battleReportCompleter = Completer<void>();
    overlays.add(overlayBattleReport);
    await _battleReportCompleter!.future;
    if (_state == GameState.menu) return;

    // Remove markers now that the new turn begins
    for (final m in _battleMarkers) { m.removeFromParent(); }
    _battleMarkers.clear();

    // 7. Check win / lose conditions
    final winResult = _checkWinConditions();
    if (winResult != null) {
      _handleGameEnd(winResult);
      return;
    }

    // 8. Brief turn-start pause
    _showMessage('Turn $_currentTurn start!');
    await Future.delayed(const Duration(seconds: 3));
    overlays.remove(overlayMessage);

    unawaited(_saveGameState());
    _state = GameState.playing;
    onHudChanged?.call();
  }

  void dismissBattleReport() {
    overlays.remove(overlayBattleReport);
    _battleReportCompleter?.complete();
    _battleReportCompleter = null;
  }

  void backToMenu() => _showMenu();

  WinResult? _checkWinConditions() {
    // Home base capture — checked first and immediately decisive
    if (_playerHomeBase != null && _playerHomeBase!.isMounted &&
        _playerHomeBase!.owner != 'player') {
      return WinResult.playerHomeBaseLost;
    }
    if (_enemyHomeBase != null && _enemyHomeBase!.isMounted &&
        !_isEnemy(_enemyHomeBase!.owner)) {
      return WinResult.enemyHomeBaseLost;
    }

    final allStars      = _stars.where((s) => s.isMounted).toList();
    final total         = allStars.length;
    if (total == 0) return null;

    final playerStarCount = allStars.where((s) => s.owner == 'player').length;
    final enemyStarCount  = allStars.where((s) => _isEnemy(s.owner)).length;

    // Elimination
    if (enemyStarCount == 0 && playerStarCount > 0) return WinResult.playerElimination;
    if (playerStarCount == 0)                        return WinResult.playerDefeated;

    // 80% conquest
    final threshold = (total * 0.8).ceil();
    if (playerStarCount >= threshold) return WinResult.playerConquest;
    if (enemyStarCount  >= threshold) return WinResult.enemyConquest;

    // Dominance surrender: ≥20 stars and 4× stars AND 4× total ships (stars + fleets)
    if (playerStarCount >= 20 && playerStarCount >= enemyStarCount * 4) {
      final playerShips = allStars.where((s) => s.owner == 'player').fold(0, (n, s) => n + s.ships)
          + _fleets.where((f) => f.owner == 'player').fold(0, (n, f) => n + f.ships);
      final enemyShips  = allStars.where((s) => _isEnemy(s.owner)).fold(0, (n, s) => n + s.ships)
          + _fleets.where((f) => _isEnemy(f.owner)).fold(0, (n, f) => n + f.ships);
      if (enemyShips == 0 || playerShips >= enemyShips * 4) return WinResult.playerDominance;
    }

    return null;
  }

  // ─── Special stars & disasters ───────────────────────────────────────────

  void _applyNaturalDisasters(math.Random rand) {
    for (final star in _stars.toList()) {
      if (!star.isMounted) continue;
      if (star == _playerHomeBase || star == _enemyHomeBase) continue; // immune
      if (rand.nextDouble() >= 0.002) continue; // 1 in 500
      final ownerDesc = star.owner == 'player' ? 'one of your stars'
          : _isEnemy(star.owner) ? 'an enemy star'
          : 'a neutral star';
      if (rand.nextBool()) {
        // Supernova: star destroyed
        _eventQueue.add(GameEvent(
          title: 'Supernova!',
          detail: 'A catastrophic supernova has destroyed $ownerDesc!\nAll ${star.ships} ships were lost.',
          star: star,
          accentColor: const Color(0xFFFF9800),
        ));
        if (star.owner == 'player') { shipsLost += star.ships; }
        _captureRings.remove(star)?.removeFromParent();
        _wormholeRings.remove(star)?.removeFromParent();
        _stars.remove(star);
        star.removeFromParent();
      } else {
        // Population collapse: ships, resources, defence → 0
        _eventQueue.add(GameEvent(
          title: 'Population Collapse!',
          detail: 'Internal catastrophe has ravaged $ownerDesc.\nShips, production, and defence have been lost.',
          star: star,
          accentColor: const Color(0xFFFF9800),
        ));
        if (star.owner == 'player') { shipsLost += star.ships; }
        star.ships = 0;
        star.resources = 0;
        star.defence = 0;
      }
    }
  }

  Future<void> _processEventQueue() async {
    for (final event in _eventQueue) {
      if (_state == GameState.menu) break;
      if (event.star != null && event.star!.isMounted) {
        _focusCameraOnStar(event.star!);
        _showEventRing(event.star!);
      }
      _currentEvent = event;
      overlays.add(overlayEvent);
      await Future.delayed(const Duration(seconds: 5));
      overlays.remove(overlayEvent);
      _currentEvent = null;
      _hideEventRing();
    }
    _eventQueue.clear();
  }

  void _focusCameraOnStar(StarComponent star) {
    const zoom = 1.5;
    camera.viewfinder.zoom = zoom;
    camera.viewfinder.position = Vector2(
      star.position.x - size.x / (2 * zoom),
      star.position.y - size.y / (2 * zoom),
    );
    _clampCamera();
  }

  void _showEventRing(StarComponent star) {
    _eventRingComponent?.removeFromParent();
    final r = math.max(30.0, star.radius) * 2.5;
    _eventRingComponent = EventRing(starPosition: star.position.clone(), radius: r);
    world.add(_eventRingComponent!);
  }

  void _hideEventRing() {
    _eventRingComponent?.removeFromParent();
    _eventRingComponent = null;
  }

  void _pairWormholes() {
    final wormholes = _stars.where((s) => s.specialType == SpecialStarType.wormhole).toList();
    for (int i = 0; i + 1 < wormholes.length; i += 2) {
      wormholes[i].wormholeTarget     = wormholes[i + 1];
      wormholes[i + 1].wormholeTarget = wormholes[i];
      // Rings are hidden until discovered by exploration — added in _discoverWormhole
    }
    // Odd one out: downgrade to friendly encounter
    if (wormholes.length.isOdd) {
      wormholes.last.specialType = SpecialStarType.friendlyEncounter;
    }
  }

  void _discoverAncientTech(StarComponent star, math.Random rand) {
    final available = Technology.values.where((t) => !_playerTechs.contains(t)).toList();
    if (available.isEmpty) {
      _eventQueue.add(GameEvent(
        title: 'Ancient Ruins Found!',
        detail: 'Your scientists examine the ruins but find nothing new.\nAll technologies have already been mastered.',
        star: star,
        accentColor: const Color(0xFFFFD700),
      ));
      return;
    }
    final tech = available[rand.nextInt(available.length)];
    _playerTechs.add(tech);
    _eventQueue.add(GameEvent(
      title: 'Ancient Technology Discovered!',
      detail: '${tech.displayName}\n${tech.description}',
      star: star,
      accentColor: const Color(0xFFFFD700),
    ));
  }

  void _discoverWormhole(StarComponent star) {
    if (star.wormholeDiscovered) return;
    star.wormholeDiscovered = true;
    _addWormholeRing(star);
    _eventQueue.add(GameEvent(
      title: 'Wormhole Discovered!',
      detail: 'Your fleet has found a wormhole!\nSelect this star and tap WARP to transit ships.',
      star: star,
      accentColor: const Color(0xFF00E5FF),
    ));
  }

  void _addWormholeRing(StarComponent star) {
    final r = math.max(20.0, star.radius) * 2.2;
    final ring = WormholeRing(starPosition: star.position.clone(), radius: r);
    _wormholeRings[star] = ring;
    world.add(ring);
  }

  void _handleGameEnd(WinResult result) {
    _gameResult = result;
    overlays.remove(overlayHud);
    overlays.remove(overlayMessage);
    overlays.add(overlayGameResult);
    unawaited(StorageService.clearSave());
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  Future<void> _saveGameState() async {
    final starSaves = <StarSave>[];
    for (final star in _stars) {
      if (!star.isMounted) continue;
      starSaves.add(StarSave(
        x: star.position.x,
        y: star.position.y,
        size: switch (star.config.size) {
          StarSize.light  => 'light',
          StarSize.medium => 'medium',
          StarSize.large  => 'large',
        },
        iconKey: _homeStarIconKey(star),
        owner: star.owner,
        ships: star.ships,
        resources: star.resources,
        defence: star.defence,
        specialType: star.specialType.name,
        wormholeTargetIndex: star.wormholeTarget != null
            ? _stars.indexOf(star.wormholeTarget!)
            : -1,
        wormholeDiscovered: star.wormholeDiscovered,
      ));
    }

    final fleetSaves = <FleetSave>[];
    for (final fleet in _fleets) {
      final originIdx = _stars.indexOf(fleet.origin);
      final destIdx   = _stars.indexOf(fleet.destination);
      if (originIdx < 0 || destIdx < 0) continue;
      fleetSaves.add(FleetSave(
        originIndex: originIdx,
        destIndex: destIdx,
        owner: fleet.owner,
        ships: fleet.ships,
        turnsRemaining: fleet.turnsRemaining,
        totalTurns: fleet.totalTurns,
      ));
    }

    await StorageService.saveGame(GameSave(
      turn: _currentTurn,
      seed: _universeRngSeed,
      stars: starSaves,
      fleets: fleetSaves,
      technologies: _playerTechs.map((t) => t.name).toList(),
    ));
  }

  // Home stars use icon sprites; neutral stars use star sprites.
  // Infer by matching the two fixed home positions.
  String? _homeStarIconKey(StarComponent star) {
    const eps = 1.0;
    if ((star.position.x - playerStarX).abs() < eps &&
        (star.position.y - playerStarY).abs() < eps) { return 'enemy_blue'; }
    if ((star.position.x - enemyStarX).abs() < eps &&
        (star.position.y - enemyStarY).abs() < eps) { return 'enemy_red'; }
    return null;
  }

  void _buildStarsFromSave(GameSave save) {
    for (final ss in save.stars) {
      final sz = switch (ss.size) {
        'light'  => StarSize.light,
        'medium' => StarSize.medium,
        _        => StarSize.large,
      };

      final Sprite? sprite;
      final double scale;

      if (ss.iconKey != null) {
        // Home-style star: place the large star background then the icon
        final bgSp = _sprites['star_large'];
        if (bgSp != null) {
          world.add(SpriteComponent(
            sprite: bgSp,
            position: Vector2(ss.x, ss.y),
            anchor: Anchor.center,
            scale: Vector2.all(4.5),
          ));
        }
        sprite = _sprites[ss.iconKey];
        scale  = 3.0;
      } else {
        sprite = _sprites[switch (sz) {
          StarSize.light  => 'star_light',
          StarSize.medium => 'star_medium',
          StarSize.large  => 'star_large',
        }];
        scale = switch (sz) {
          StarSize.light  => 2.0,
          StarSize.medium => 3.0,
          StarSize.large  => 4.0,
        };
      }

      if (sprite == null) continue;

      final star = StarComponent(
        config: StarConfig(
          size: sz, x: ss.x, y: ss.y,
          owner: ss.owner,
          ships: ss.ships, resources: ss.resources, defence: ss.defence,
        ),
        sprite: sprite,
      )..position = Vector2(ss.x, ss.y)..scale = Vector2.all(scale);

      star.specialType = switch (ss.specialType) {
        'friendlyEncounter' => SpecialStarType.friendlyEncounter,
        'ancientTrap'       => SpecialStarType.ancientTrap,
        'wormhole'          => SpecialStarType.wormhole,
        _                   => SpecialStarType.none,
      };

      _stars.add(star);
      world.add(star);

      if (ss.owner != null) _applyCaptureRing(star, ss.owner!);
    }

    // Identify home bases by their fixed positions
    for (final star in _stars) {
      const eps = 1.0;
      if ((star.position.x - playerStarX).abs() < eps &&
          (star.position.y - playerStarY).abs() < eps) {
        _playerHomeBase = star;
      }
      if ((star.position.x - enemyStarX).abs() < eps &&
          (star.position.y - enemyStarY).abs() < eps) {
        _enemyHomeBase = star;
      }
    }

    // Wire up wormhole connections; restore rings only for already-discovered stars
    for (int i = 0; i < save.stars.length && i < _stars.length; i++) {
      final wti = save.stars[i].wormholeTargetIndex;
      if (wti >= 0 && wti < _stars.length) {
        _stars[i].wormholeTarget = _stars[wti];
      }
      if (_stars[i].specialType == SpecialStarType.wormhole &&
          save.stars[i].wormholeDiscovered) {
        _stars[i].wormholeDiscovered = true;
        _addWormholeRing(_stars[i]);
      }
    }

    // Restore technologies
    _playerTechs.addAll(
      save.technologies.expand((n) => Technology.values.where((t) => t.name == n)),
    );

    // Restore in-transit fleets
    for (final fs in save.fleets) {
      if (fs.originIndex >= _stars.length || fs.destIndex >= _stars.length) continue;
      final fleet = Fleet(
        owner: fs.owner,
        origin: _stars[fs.originIndex],
        destination: _stars[fs.destIndex],
        ships: fs.ships,
        turnsRemaining: fs.turnsRemaining,
        totalTurns: fs.totalTurns,
      );
      _fleets.add(fleet);
      _addFleetMarker(fleet);
    }
  }

  void _advanceFleets(String owner, math.Random rand) {
    final arrived = <Fleet>[];
    for (final f in _fleets.where((f) => f.owner == owner)) {
      f.turnsRemaining--;
      if (f.turnsRemaining <= 0) arrived.add(f);
    }

    // Group fleets that arrive at the same destination this turn and combine ships
    final Map<StarComponent, int> combined = {};
    for (final f in arrived) {
      combined[f.destination] = (combined[f.destination] ?? 0) + f.ships;
    }
    for (final entry in combined.entries) {
      _processArrival(owner, entry.key, entry.value, rand);
    }

    for (final f in arrived) {
      _removeFleetMarker(f);
      _fleets.remove(f);
    }
  }

  void _processArrival(String owner, StarComponent dest, int ships, math.Random rand) {
    if (!dest.isMounted) return;

    // ─── Ancient Trap ─────────────────────────────────────────────────────
    if (dest.specialType == SpecialStarType.ancientTrap) {
      dest.specialType = SpecialStarType.none; // trap sprung — gone forever
      final isPlayer = owner == 'player';
      _eventQueue.add(GameEvent(
        title: 'Ancient Trap!',
        detail: isPlayer
            ? 'Your fleet of $ships ships was obliterated\nby an ancient automated defence system!'
            : 'An enemy fleet of $ships ships was destroyed\nby an ancient automated defence system!',
        star: dest,
        accentColor: const Color(0xFFFF6B6B),
      ));
      if (isPlayer) { battlesLost++; shipsLost += ships; }
      onHudChanged?.call();
      return;
    }

    // ─── Friendly Encounter (player only) ────────────────────────────────
    if (owner == 'player' && dest.specialType == SpecialStarType.friendlyEncounter) {
      final bonus = rand.nextInt(20) + 1;
      dest.specialType = SpecialStarType.none;
      dest.owner = 'player';
      dest.ships += ships + bonus;
      _applyCaptureRing(dest, 'player');
      _eventQueue.add(GameEvent(
        title: 'Special Star Found!',
        detail: 'A friendly civilisation offers to join your empire!\n+$bonus bonus ships added.',
        star: dest,
        accentColor: const Color(0xFFFF80AB),
      ));
      battlesWon++;
      starsGained++;
      onHudChanged?.call();
      return;
    }

    // ─── Friendly reinforcement ───────────────────────────────────────────
    if (dest.owner == owner) {
      dest.ships += ships;
      if (owner == 'player' && dest.specialType == SpecialStarType.wormhole) {
        _discoverWormhole(dest);
      }
      onHudChanged?.call();
      return;
    }

    // ─── Battle ───────────────────────────────────────────────────────────
    final prevOwner        = dest.owner;
    int attackers          = ships;
    final initialAttackers = attackers;
    int defenders          = dest.ships;
    final initialDefenders = defenders;
    final defence          = dest.defence;
    final isPlayerAtk      = owner == 'player';
    final isPlayerDef      = prevOwner == 'player';

    // Alter Reality: 10% chance defenders switch sides before battle
    if (isPlayerAtk && hasTech(Technology.alterReality) && rand.nextDouble() < 0.1) {
      attackers += defenders;
      defenders  = 0;
    }

    // Force Fields: auto-destroy first 2 attackers when player defends
    if (isPlayerDef && hasTech(Technology.forceFields)) {
      attackers = math.max(0, attackers - 2);
    }

    // Surprise Attack: player gets a free kill before battle
    if (isPlayerAtk && hasTech(Technology.surpriseAttack) && defenders > 0) {
      defenders--;
    }
    // Surprise Defence: player defending gets a free kill on attackers
    if (isPlayerDef && hasTech(Technology.surpriseDefence) && attackers > 0) {
      attackers--;
    }

    // Helper: single attack roll respecting Improved Weapon Capacity
    int singleRoll() => isPlayerAtk && hasTech(Technology.improvedWeaponCapacity)
        ? rand.nextInt(11) + 1
        : rand.nextInt(10) + 1;

    int adaptiveBonus = 0; // Adaptive Shields — grows each time attacker misses

    while (attackers > 0 && defenders > 0) {
      // Attacker roll — Ion Cannon rolls twice and takes the higher
      var atkRoll = isPlayerAtk && hasTech(Technology.ionCannon)
          ? math.max(singleRoll(), singleRoll())
          : singleRoll();

      if (isPlayerAtk && hasTech(Technology.quantumAttack) && rand.nextDouble() < 0.1) {
        atkRoll = math.min(atkRoll * 2, 20);
      }
      if (isPlayerAtk && hasTech(Technology.advancedWeapons)) atkRoll++;
      // Berserker Protocol: last surviving attacker gets +3
      if (isPlayerAtk && hasTech(Technology.berserkerProtocol) && attackers == 1) atkRoll += 3;

      // Attack threshold
      int effectiveDefence = defence + adaptiveBonus;
      if (isPlayerDef && hasTech(Technology.advancedStarDefence)) effectiveDefence++;
      if (isPlayerDef && hasTech(Technology.advancedShipDefence)) effectiveDefence++;
      // Precision Targeting: treat defence as 1 lower
      if (isPlayerAtk && hasTech(Technology.precisionTargeting)) {
        effectiveDefence = math.max(0, effectiveDefence - 1);
      }
      final baseThreshold = isPlayerAtk && hasTech(Technology.improvedWeaponStrength) ? 5 : 6;
      final atkThreshold  = math.min(10, baseThreshold + effectiveDefence);

      if (atkRoll >= atkThreshold) {
        defenders--;
      } else if (isPlayerDef && hasTech(Technology.adaptiveShields)) {
        adaptiveBonus++; // attacker missed — shields learn and adapt
      }
      if (defenders <= 0) break;

      // Defender roll — player attackers harder to kill with advancedShipDefence
      final defThreshold = isPlayerAtk && hasTech(Technology.advancedShipDefence) ? 7 : 6;
      if (rand.nextInt(10) + 1 >= defThreshold) attackers--;
    }

    // Surviving ships stay at the star — not the starting count, the remainder
    if (attackers > 0) {
      // Stellar Recycling: recover 25% of attacker ships lost (rounded up)
      if (isPlayerAtk && hasTech(Technology.stellarRecycling)) {
        attackers += ((initialAttackers - attackers) * 0.25).ceil();
      }
      dest.ships = attackers;
      dest.owner = owner;
      _applyCaptureRing(dest, owner);
      if (isPlayerAtk && dest.specialType == SpecialStarType.wormhole) {
        _discoverWormhole(dest);
      }
      if (isPlayerAtk && dest.specialType == SpecialStarType.ancientRuins) {
        dest.specialType = SpecialStarType.none;
        _discoverAncientTech(dest, rand);
      }
      if (isPlayerAtk) {
        battlesWon++;
        starsGained++;
        shipsLost += initialAttackers - attackers;
        _addBattleMarker(dest, won: true);
      } else if (isPlayerDef) {
        battlesLost++;
        starsLost++;
        shipsLost += initialDefenders;
        _addBattleMarker(dest, won: false);
      }
    } else {
      dest.ships = defenders;
      if (isPlayerAtk) {
        battlesLost++;
        shipsLost += initialAttackers;
        _addBattleMarker(dest, won: false);
      }
    }
    onHudChanged?.call();
  }

  void _addBattleMarker(StarComponent star, {required bool won}) {
    final r = math.max(20.0, star.radius);
    if (won) {
      final m = BattleWonMarker(starPosition: star.position.clone(), radius: r * 1.7);
      _battleMarkers.add(m);
      world.add(m);
    } else {
      final m = BattleLostMarker(starPosition: star.position.clone(), armLength: r * 1.2);
      _battleMarkers.add(m);
      world.add(m);
    }
  }

  // ─── Enemy AI ─────────────────────────────────────────────────────────────

  void _runEnemyAI(math.Random rand) {
    // 1. Strategic assessment: attempt a home-base assault if conditions are met
    _tryEnemyHomeBaseAssault(rand);

    // 2. Auto-move style: process stars in descending ship-count order
    final enemyStars = _stars
        .where((s) => _isEnemy(s.owner) && s.ships > 2 && s.isMounted)
        .toList()
      ..sort((a, b) => b.ships.compareTo(a.ships));

    final playerStarList = _stars
        .where((s) => s.owner == 'player' && s.isMounted)
        .toList();

    for (final star in enemyStars) {
      // Home base: enforce minimum garrison before sending any ships
      final minGarrison = (star == _enemyHomeBase)
          ? _enemyHomeBaseMinGarrison(playerStarList)
          : 1;
      final available = star.ships - minGarrison;
      if (available <= 0) continue;

      // Find closest non-enemy star
      final targets = _stars
          .where((s) => s.owner != star.owner && s.isMounted)
          .toList()
        ..sort((a, b) => (a.position - star.position).length2
            .compareTo((b.position - star.position).length2));

      if (targets.isEmpty) continue;
      final target = targets.first;

      // Strategic conservatism: frontline stars keep more ships
      double nearestPlayer = double.infinity;
      for (final ps in playerStarList) {
        final d = (star.position - ps.position).length;
        if (d < nearestPlayer) nearestPlayer = d;
      }

      final maxFraction = nearestPlayer < 400 ? 0.25
          : nearestPlayer < 800              ? 0.55
          :                                    0.85;

      final maxSend = math.min(available, math.max(1, (star.ships * maxFraction).round()));
      final shipsToSend = rand.nextInt(maxSend) + 1;
      if (shipsToSend >= star.ships) continue;

      star.ships -= shipsToSend;
      final d = (star.position - target.position).length;
      final turns = math.max(1, (d / travelSpeed).ceil());
      _fleets.add(Fleet(
        owner: star.owner!,
        origin: star,
        destination: target,
        ships: shipsToSend,
        turnsRemaining: turns,
      ));
      _addFleetMarker(_fleets.last);
    }
  }

  // Returns the minimum ships the enemy must keep at its home base.
  // Uses only observable information: player star positions and fleet marker presence.
  int _enemyHomeBaseMinGarrison(List<StarComponent> playerStarList) {
    if (_enemyHomeBase == null) return 5;

    // Count visible player stars by proximity — the enemy sees colored dots, not ship counts
    int threatScore = 0;
    for (final ps in playerStarList) {
      final d = (ps.position - _enemyHomeBase!.position).length;
      if (d < 500)            { threatScore += 4; }
      else if (d < 900)       { threatScore += 2; }
      else if (d < 1400)      { threatScore += 1; }
    }

    // Count player fleet MARKERS heading toward home base (enemy sees the marker, not the ships)
    final inboundMarkerCount = _fleets
        .where((f) => f.owner == 'player' && f.destination == _enemyHomeBase)
        .length;
    // Each visible fleet marker is assumed to represent ~10 ships (rough estimate)
    final estimatedInboundThreat = inboundMarkerCount * 10;

    return math.max(5, threatScore * 3 + estimatedInboundThreat);
  }

  // Decides whether to launch a focused assault on the player's home base.
  // The enemy uses only observable data plus estimates — no peeking at player ship counts.
  void _tryEnemyHomeBaseAssault(math.Random rand) {
    if (_playerHomeBase == null || !_playerHomeBase!.isMounted) return;
    if (_playerHomeBase!.owner != 'player') return;

    // Enemy knows its OWN total strength perfectly
    final totalEnemyShips = _stars
            .where((s) => _isEnemy(s.owner) && s.isMounted)
            .fold(0, (n, s) => n + s.ships)
        + _fleets
            .where((f) => _isEnemy(f.owner))
            .fold(0, (n, f) => n + f.ships);

    // Enemy ESTIMATES player strength from visible star count only
    // (assumes roughly 8 ships per player star — a rough, imperfect heuristic)
    final visiblePlayerStars = _stars
        .where((s) => s.owner == 'player' && s.isMounted)
        .length;
    final estimatedPlayerStrength = visiblePlayerStars * 8;

    // Randomising factor: enemy confidence varies ±20% each turn
    final confidenceFactor = 0.8 + rand.nextDouble() * 0.4; // 0.8–1.2
    final perceivedAdvantage =
        (totalEnemyShips / math.max(1, estimatedPlayerStrength)) * confidenceFactor;

    // Find best non-home attack candidate closest to player home base
    final candidates = _stars
        .where((s) => _isEnemy(s.owner) && s.isMounted &&
            s != _enemyHomeBase && s.ships > 4)
        .toList()
      ..sort((a, b) => (a.position - _playerHomeBase!.position).length2
          .compareTo((b.position - _playerHomeBase!.position).length2));

    if (candidates.isEmpty) return;
    final closest = candidates.first;

    // Decide to assault if:
    //  a) Enemy feels it has a strong overall advantage (≥1.8× estimated player), OR
    //  b) Closest star has accumulated a large force AND a random boldness check fires
    final boldnessRoll    = rand.nextDouble();
    final shouldAssault   = perceivedAdvantage >= 1.8 ||
        (closest.ships >= 25 && boldnessRoll < 0.25);

    if (!shouldAssault) return;

    // Send 70% of the closest star's ships — minimum 5 to avoid token assaults
    final shipsToSend = math.max(1, (closest.ships * 0.70).round());
    if (shipsToSend < 5) return;

    closest.ships -= shipsToSend;
    final d     = (closest.position - _playerHomeBase!.position).length;
    final turns = math.max(1, (d / travelSpeed).ceil());
    _fleets.add(Fleet(
      owner: closest.owner!,
      origin: closest,
      destination: _playerHomeBase!,
      ships: shipsToSend,
      turnsRemaining: turns,
    ));
    _addFleetMarker(_fleets.last);
  }

  // ─── Fleet marker helpers ─────────────────────────────────────────────────

  void _addFleetMarker(Fleet fleet) {
    final marker = FleetMarker(fleet: fleet)..updatePosition();
    _fleetMarkers[fleet] = marker;
    world.add(marker);
  }

  void _removeFleetMarker(Fleet fleet) {
    _fleetMarkers.remove(fleet)?.removeFromParent();
  }

  // ─── Capture ring helpers ──────────────────────────────────────────────────

  void _applyCaptureRing(StarComponent star, String owner) {
    _captureRings.remove(star)?.removeFromParent();
    final color = owner == 'player'
        ? const Color(0xFF42A5F5) // blue
        : const Color(0xFFEF5350); // red
    final ringMult = switch (star.config.size) {
      StarSize.light  => 3.2,
      StarSize.medium => 2.4,
      StarSize.large  => 1.8,
    };
    final ring = CaptureRing(
      color: color,
      ringRadius: star.radius * ringMult,
      starPosition: star.position.clone(),
    );
    _captureRings[star] = ring;
    world.add(ring);
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  void handleTap(Vector2 screenPos) {
    if (_state != GameState.playing) return;
    final worldPos = camera.viewfinder.position + screenPos / camera.viewfinder.zoom;

    // Fleet markers take priority
    for (final marker in _fleetMarkers.values) {
      if (!marker.isMounted) continue;
      final d = worldPos - marker.position;
      if (d.length2 <= (marker.radius * 2) * (marker.radius * 2)) {
        _selectMarker(marker);
        return;
      }
    }

    // Stars
    for (final star in _stars) {
      if (!star.isMounted) continue;
      final d = worldPos - star.position;
      if (d.length2 <= star.tapRadius * star.tapRadius) {
        _onStarTapped(star);
        return;
      }
    }

    _deselectAll();
  }

  void _selectMarker(FleetMarker marker) {
    _deselectAll();
    _selectedMarker?.isSelected = false;
    marker.isSelected = true;
    _selectedMarker = marker;
  }

  void _onStarTapped(StarComponent star) {
    _selectedMarker?.isSelected = false;
    _selectedMarker = null;

    if (_selectedStar != null && star != _selectedStar) {
      _peekedStar = null;
      _setTargetStar(star);
    } else if (_selectedStar == null && star.owner == 'player') {
      _peekedStar = null;
      _setFirstStar(star);
    } else if (_selectedStar == null && hasTech(Technology.quantumVision)) {
      // Quantum Vision: reveal non-player star stats
      _peekedStar = star;
      overlays.add(overlayStarInfo);
      onStarSelected?.call(star);
    } else {
      _deselectAll();
    }
  }

  void _setFirstStar(StarComponent star) {
    _ring1?.removeFromParent();
    final selSp = _sprites['select_green'];
    if (selSp != null) {
      _ring1 = SpriteComponent(
        sprite: selSp, position: star.position,
        anchor: Anchor.center, scale: star.scale * 1.5,
      );
      world.add(_ring1!);
    }
    _selectedStar = star;
    _shipsToSend = math.max(1, star.ships ~/ 2);
    overlays.remove(overlayAction);
    overlays.add(overlayStarInfo);
    onStarSelected?.call(star);
    onHudChanged?.call();
  }

  void _setTargetStar(StarComponent star) {
    _ring2?.removeFromParent();
    _connectionLine?.removeFromParent();
    final selSp = _sprites['select_green'];
    if (selSp != null) {
      _ring2 = SpriteComponent(
        sprite: selSp, position: star.position,
        anchor: Anchor.center, scale: star.scale * 1.5,
      );
      world.add(_ring2!);
    }
    _connectionLine = ConnectionLine(
      from: _selectedStar!.position.clone(),
      to: star.position.clone(),
    );
    world.add(_connectionLine!);
    _targetStar = star;
    _shipsToSend = _shipsToSend.clamp(1, _selectedStar!.ships);
    overlays.remove(overlayStarInfo);
    overlays.add(overlayAction);
    onActionChanged?.call();
  }


  void _deselectAll() {
    _ring1?.removeFromParent();
    _ring2?.removeFromParent();
    _connectionLine?.removeFromParent();
    _ring1 = null; _ring2 = null; _connectionLine = null;
    _selectedStar = null; _targetStar = null; _shipsToSend = 0;
    _selectedMarker?.isSelected = false;
    _selectedMarker = null;
    _pendingAutoMoveStar = null;
    _peekedStar = null;
    overlays.remove(overlayStarInfo);
    overlays.remove(overlayAction);
    onStarSelected?.call(null);
    onActionChanged?.call();
  }

  void handlePanZoom({required Vector2 panDelta, required double newZoom, required Vector2 focal}) {
    if (_state == GameState.menu) return;
    final oldZoom = camera.viewfinder.zoom;
    if ((newZoom - oldZoom).abs() > 0.001) {
      camera.viewfinder.position += focal * (1.0 / oldZoom - 1.0 / newZoom);
      camera.viewfinder.zoom = newZoom;
    }
    if (panDelta.length2 > 0) camera.viewfinder.position -= panDelta / camera.viewfinder.zoom;
    _clampCamera();
  }

  void _clampCamera() {
    final z = camera.viewfinder.zoom;
    final maxX = (universeWidth  - size.x / z).clamp(0.0, universeWidth);
    final maxY = (universeHeight - size.y / z).clamp(0.0, universeHeight);
    final pos = camera.viewfinder.position;
    pos.x = pos.x.clamp(0.0, maxX);
    pos.y = pos.y.clamp(0.0, maxY);
    camera.viewfinder.position = pos;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
    camera.viewfinder.anchor = Anchor.topLeft;
    await _loadSprites();
    await adsService.load();
    _showMenu();
  }

  Future<void> _loadSprites() async {
    const names = [
      'star_light', 'star_medium', 'star_large',
      'nebula_red', 'nebula_blue', 'select_green',
      'enemy_blue', 'enemy_red', 'enemy_grey',
    ];
    for (final n in names) {
      try { _sprites[n] = await Sprite.load('img/$n.png'); } catch (_) {}
    }
  }

  // ─── Menu ─────────────────────────────────────────────────────────────────

  void _showMenu() {
    _state = GameState.menu;
    _stopMusic();
    overlays.remove(overlayBattleReport);
    _battleReportCompleter?.complete();
    _battleReportCompleter = null;
    _clearAll();
    _spawnMenuStarfield();
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = 1.0;
    overlays
      ..remove(overlayHud)
      ..remove(overlayMessage)
      ..remove(overlayStarInfo)
      ..remove(overlayAction)
      ..remove(overlayGameResult)
      ..add(overlayMenu);
    _playMusic('Title_Music.wav');
  }

  void _spawnMenuStarfield() {
    final rand = math.Random();
    final w = size.x; final h = size.y;
    for (final (name, count, scale) in <(String, int, double)>[
      ('star_light', 80, 2.0), ('star_medium', 40, 3.0), ('star_large', 15, 4.0),
      ('nebula_red', 1, 5.0), ('nebula_blue', 2, 5.0),
    ]) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        world.add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * w, rand.nextDouble() * h),
          anchor: Anchor.center, scale: Vector2.all(scale),
        ));
      }
    }
  }

  // ─── Game start ───────────────────────────────────────────────────────────

  Future<void> startGame() async {
    overlays.remove(overlayMenu);
    overlays.add(overlayHud);
    _clearAll();
    _currentTurn = 1;
    _state = GameState.transitioning;
    camera.viewfinder.zoom = 1.0;
    _universeRngSeed = DateTime.now().millisecondsSinceEpoch;
    _buildUniverse(math.Random(_universeRngSeed));
    unawaited(StorageService.clearSave());
    _stopMusic();
    _playMusic('level_music.wav');
    camera.viewfinder.position = Vector2(playerStarX - size.x / 2, playerStarY - size.y / 2);
    _showMessage('Home Star - Start!');
    await Future.delayed(const Duration(seconds: 2));
    overlays.remove(overlayMessage);
    _state = GameState.playing;
    onHudChanged?.call();
  }

  Future<void> continueGame() async {
    final save = await StorageService.loadGame();
    if (save == null) { await startGame(); return; }

    overlays.remove(overlayMenu);
    overlays.add(overlayHud);
    _clearAll();
    _currentTurn = save.turn;
    _universeRngSeed = save.seed;
    _state = GameState.transitioning;
    camera.viewfinder.zoom = 1.0;

    _buildCosmetics(math.Random(save.seed));
    _buildStarsFromSave(save);

    _stopMusic();
    _playMusic('level_music.wav');

    final home = _stars.firstWhere(
      (s) => s.owner == 'player',
      orElse: () => _stars.first,
    );
    camera.viewfinder.position = Vector2(
      home.position.x - size.x / 2,
      home.position.y - size.y / 2,
    );
    _clampCamera();

    _state = GameState.playing;
    onHudChanged?.call();
  }

  // ─── Universe ─────────────────────────────────────────────────────────────

  void _buildUniverse(math.Random rand) {
    _buildCosmetics(rand);

    final n = neutralStarCount;
    _spawnNeutralStars('star_large',  StarSize.large,  (n * 0.15).round(), rand);
    _spawnNeutralStars('star_medium', StarSize.medium, (n * 0.35).round(), rand);
    _spawnNeutralStars('star_light',  StarSize.light,  n - (n * 0.15).round() - (n * 0.35).round(), rand);

    _playerHomeBase = _spawnOccupiedStar(x: playerStarX, y: playerStarY, owner: 'player',    iconKey: 'enemy_blue', ships: 10, resources: 3, defence: 1);
    _enemyHomeBase  = _spawnOccupiedStar(x: enemyStarX,  y: enemyStarY,  owner: 'enemy_red', iconKey: 'enemy_red',  ships: 10, resources: 3, defence: 1);
    _pairWormholes();
  }

  void _buildCosmetics(math.Random rand) {
    for (final (name, count, scale) in <(String, int, double)>[
      ('nebula_red', 3, 6.0), ('nebula_blue', 4, 6.0),
    ]) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        world.add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * universeWidth, rand.nextDouble() * universeHeight),
          anchor: Anchor.center, scale: Vector2.all(scale),
        ));
      }
    }
    final bgSp = _sprites['star_light'];
    if (bgSp != null) {
      for (int i = 0; i < 160; i++) {
        world.add(SpriteComponent(
          sprite: bgSp,
          position: Vector2(rand.nextDouble() * universeWidth, rand.nextDouble() * universeHeight),
          anchor: Anchor.center, scale: Vector2.all(1.5),
        ));
      }
    }
  }

  void _spawnNeutralStars(String spriteName, StarSize sz, int count, math.Random rand) {
    final sp = _sprites[spriteName];
    if (sp == null) return;
    final scale = switch (sz) { StarSize.light => 2.0, StarSize.medium => 3.0, StarSize.large => 4.0 };
    for (int i = 0; i < count; i++) {
      double x, y;
      do {
        x = rand.nextDouble() * (universeWidth - 100) + 50;
        y = rand.nextDouble() * (universeHeight - 100) + 50;
      } while (_tooCloseToHome(x, y));
      final star = StarComponent(
        config: StarConfig(size: sz, x: x, y: y,
            ships: _randomShips(rand), resources: _randomResources(rand), defence: _randomDefence(rand)),
        sprite: sp,
      )..position = Vector2(x, y)..scale = Vector2.all(scale);
      // 10% chance of being a special star (4 types, equal probability)
      if (rand.nextDouble() < 0.10) {
        final t = rand.nextDouble();
        if (t < 0.25) {
          star.specialType = SpecialStarType.friendlyEncounter;
        } else if (t < 0.50) {
          star.specialType = SpecialStarType.ancientTrap;
        } else if (t < 0.75) {
          star.specialType = SpecialStarType.wormhole; // paired later
        } else {
          star.specialType = SpecialStarType.ancientRuins;
        }
      }
      _stars.add(star);
      world.add(star);
    }
  }

  StarComponent _spawnOccupiedStar({
    required double x, required double y,
    required String owner, required String iconKey,
    required int ships, required int resources, required int defence,
  }) {
    final starSp = _sprites['star_large'];
    final iconSp = _sprites[iconKey];
    if (starSp == null || iconSp == null) {
      // Return a dummy star if sprites missing (shouldn't happen in practice)
      final dummy = StarComponent(
        config: StarConfig(size: StarSize.large, x: x, y: y, owner: owner,
            ships: ships, resources: resources, defence: defence),
        sprite: starSp ?? iconSp!,
      );
      return dummy;
    }
    world.add(SpriteComponent(
      sprite: starSp, position: Vector2(x, y),
      anchor: Anchor.center, scale: Vector2.all(4.5),
    ));
    final star = StarComponent(
      config: StarConfig(size: StarSize.large, x: x, y: y, owner: owner,
          ships: ships, resources: resources, defence: defence),
      sprite: iconSp,
    )..position = Vector2(x, y)..scale = Vector2.all(3.0);
    _stars.add(star);
    world.add(star);
    return star;
  }

  bool _tooCloseToHome(double x, double y) {
    const d = 150.0;
    final dpx = x - playerStarX; final dpy = y - playerStarY;
    final dex = x - enemyStarX;  final dey = y - enemyStarY;
    return (dpx*dpx + dpy*dpy) < d*d || (dex*dex + dey*dey) < d*d;
  }

  bool _isEnemy(String? owner) => owner == 'enemy_red' || owner == 'enemy_blue';

  // ─── Seeding ──────────────────────────────────────────────────────────────

  int _randomResources(math.Random r) {
    final v = r.nextDouble();
    return v < 0.80 ? 1 : v < 0.95 ? 2 : 3;
  }

  int _randomDefence(math.Random r) {
    final v = r.nextDouble();
    return v < 0.80 ? 1 : v < 0.95 ? 2 : 3;
  }

  int _randomShips(math.Random r) => r.nextInt(5) + 1;

  // ─── Message ──────────────────────────────────────────────────────────────

  void _showMessage(String text) {
    messageText = text;
    onMessageChanged?.call(text);
    overlays.add(overlayMessage);
  }

  // ─── Audio ────────────────────────────────────────────────────────────────

  void _playMusic(String f) {
    _bgm.setReleaseMode(ReleaseMode.loop);
    _bgm.play(AssetSource('sound/$f'), volume: 0.6);
  }
  void _stopMusic() => _bgm.stop();

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void _clearAll() {
    _stars.clear();
    _fleets.clear();
    _fleetMarkers.clear();
    _captureRings.clear();
    _battleMarkers.clear();
    _playerHomeBase = null;
    _enemyHomeBase  = null;
    _wormholeRings.clear();
    _eventQueue.clear();
    _currentEvent = null;
    _eventRingComponent = null;
    _playerTechs.clear();
    _peekedStar = null;
    _autoMovedStars.clear();
    _pendingAutoMoveStar = null;
    _ring1 = null; _ring2 = null; _connectionLine = null;
    _selectedStar = null; _targetStar = null; _shipsToSend = 0;
    _selectedMarker = null;
    battlesWon = battlesLost = starsGained = starsLost = shipsLost = 0;
    world.removeAll(world.children.toList());
  }
}
