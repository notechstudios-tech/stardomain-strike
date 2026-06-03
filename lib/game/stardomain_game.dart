import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/battle_marker.dart';
import '../components/capture_ring.dart';
import '../components/connection_line.dart';
import '../components/fleet_marker.dart';
import '../components/star_component.dart';
import '../models/fleet.dart';
import '../models/star_config.dart';
import '../models/game_save.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';

enum GameState { menu, playing, transitioning }

enum WinResult {
  playerElimination, // player destroyed all enemy stars
  playerConquest,    // player controls 80% of stars
  playerDominance,   // player has ≥20 stars and 4× stars & ships → enemy surrenders
  enemyConquest,     // enemy controls 80% of stars
  playerDefeated,    // player has no stars left
}

class StardomainGame extends FlameGame {
  static const String overlayMenu         = 'menu';
  static const String overlayMessage      = 'message';
  static const String overlayHud          = 'hud';
  static const String overlayStarInfo     = 'starInfo';
  static const String overlayAction       = 'action';
  static const String overlayBattleReport = 'battleReport';
  static const String overlayGameResult   = 'gameResult';

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

  Completer<void>? _battleReportCompleter;

  WinResult? _gameResult;
  WinResult? get gameResult => _gameResult;

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
    return math.max(1, (d / travelSpeed).ceil());
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
    _selectedStar!.ships -= _shipsToSend;
    final fleet = Fleet(
      owner: 'player',
      origin: _selectedStar!,
      destination: _targetStar!,
      ships: _shipsToSend,
      turnsRemaining: distanceInTurns,
    );
    _fleets.add(fleet);
    _addFleetMarker(fleet);
    _sfx.play(AssetSource('sound/select.wav'));
    _deselectAll();
    onHudChanged?.call();
  }

  // ─── Turn processing ──────────────────────────────────────────────────────

  Future<void> endTurn() async {
    if (_state != GameState.playing) return;
    _state = GameState.transitioning;
    _deselectAll();

    // Clear previous turn's markers and reset per-turn stats before resolving the new turn
    for (final m in _battleMarkers) { m.removeFromParent(); }
    _battleMarkers.clear();
    battlesWon = battlesLost = starsGained = starsLost = shipsLost = 0;

    final rand = math.Random();

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
      s.ships += s.resources;
    }
    for (final s in _stars.where((s) => _isEnemy(s.owner) && s.isMounted)) {
      s.ships += s.resources;
    }

    // 5. Update all remaining fleet marker positions
    for (final m in _fleetMarkers.values) {
      if (m.isMounted) m.updatePosition();
    }

    _currentTurn++;

    // 6. Show battle report — user can pan/zoom to inspect markers on the map
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

      _stars.add(star);
      world.add(star);

      if (ss.owner != null) _applyCaptureRing(star, ss.owner!);
    }

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
      if (f.turnsRemaining <= 0) {
        _processArrival(f, rand);
        arrived.add(f);
      }
    }
    for (final f in arrived) {
      _removeFleetMarker(f);
      _fleets.remove(f);
    }
  }

  void _processArrival(Fleet fleet, math.Random rand) {
    final dest = fleet.destination;
    if (!dest.isMounted) return;

    if (dest.owner == fleet.owner) {
      dest.ships += fleet.ships;
      onHudChanged?.call();
      return;
    }

    // ─── Battle ───────────────────────────────────────────────────────────
    final prevOwner        = dest.owner;
    int attackers          = fleet.ships;
    final initialAttackers = attackers;
    int defenders          = dest.ships;
    final initialDefenders = defenders;
    final defence          = dest.defence;

    while (attackers > 0 && defenders > 0) {
      // Attacker hits: needs (6 + defence)+ on 1-10
      final atkRoll = rand.nextInt(10) + 1;
      final atkThreshold = math.min(10, 6 + defence);
      if (atkRoll >= atkThreshold) defenders--;

      if (defenders <= 0) break;

      // Defender hits: needs 6+ on 1-10
      if (rand.nextInt(10) + 1 >= 6) attackers--;
    }

    // Surviving ships stay at the star — not the starting count, the remainder
    if (attackers > 0) {
      dest.ships = attackers; // surviving attackers inherit the star
      dest.owner = fleet.owner;
      _applyCaptureRing(dest, fleet.owner);
      // Track player-relevant outcomes
      if (fleet.owner == 'player') {
        battlesWon++;
        starsGained++;
        shipsLost += initialAttackers - attackers;
        _addBattleMarker(dest, won: true);
      } else if (prevOwner == 'player') {
        // Enemy captured a player star
        battlesLost++;
        starsLost++;
        shipsLost += initialDefenders;
        _addBattleMarker(dest, won: false);
      }
    } else {
      dest.ships = defenders; // surviving defenders hold the star
      if (fleet.owner == 'player') {
        // Player attack repelled
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
    final enemyStars = _stars
        .where((s) => _isEnemy(s.owner) && s.ships > 5 && s.isMounted)
        .toList();

    for (final star in enemyStars) {
      // Sort non-enemy stars by distance
      final targets = _stars
          .where((s) => s.owner != star.owner && s.isMounted)
          .toList()
        ..sort((a, b) => (a.position - star.position).length2
            .compareTo((b.position - star.position).length2));

      if (targets.isEmpty) continue;

      // Send to 1 or 2 nearest targets (random)
      final numTargets = math.min(rand.nextInt(2) + 1, targets.length);
      int available = star.ships;

      for (int i = 0; i < numTargets && available > 3; i++) {
        final shipsToSend = math.max(1, (available * 0.5).round());
        if (shipsToSend <= 0) continue;
        star.ships -= shipsToSend;
        available  -= shipsToSend;

        final target = targets[i];
        final d = (star.position - target.position).length;
        final turns = math.max(1, (d / travelSpeed).ceil());
        final fleet = Fleet(
          owner: star.owner!,
          origin: star,
          destination: target,
          ships: shipsToSend,
          turnsRemaining: turns,
        );
        _fleets.add(fleet);
        _addFleetMarker(fleet);
      }
    }
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
    final ring = CaptureRing(
      color: color,
      ringRadius: star.radius * 1.8,
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

    if (star.owner == 'player') {
      _clearConnection();
      _setFirstStar(star);
    } else if (_selectedStar != null) {
      _setTargetStar(star);
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

  void _clearConnection() {
    _ring2?.removeFromParent();
    _connectionLine?.removeFromParent();
    _ring2 = null;
    _connectionLine = null;
    _targetStar = null;
  }

  void _deselectAll() {
    _ring1?.removeFromParent();
    _ring2?.removeFromParent();
    _connectionLine?.removeFromParent();
    _ring1 = null; _ring2 = null; _connectionLine = null;
    _selectedStar = null; _targetStar = null; _shipsToSend = 0;
    _selectedMarker?.isSelected = false;
    _selectedMarker = null;
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

    _spawnOccupiedStar(x: playerStarX, y: playerStarY, owner: 'player',    iconKey: 'enemy_blue', ships: 10, resources: 3, defence: 1);
    _spawnOccupiedStar(x: enemyStarX,  y: enemyStarY,  owner: 'enemy_red', iconKey: 'enemy_red',  ships: 10, resources: 3, defence: 1);
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
      _stars.add(star);
      world.add(star);
    }
  }

  void _spawnOccupiedStar({
    required double x, required double y,
    required String owner, required String iconKey,
    required int ships, required int resources, required int defence,
  }) {
    final starSp = _sprites['star_large'];
    final iconSp = _sprites[iconKey];
    if (starSp == null || iconSp == null) return;
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
    _ring1 = null; _ring2 = null; _connectionLine = null;
    _selectedStar = null; _targetStar = null; _shipsToSend = 0;
    _selectedMarker = null;
    battlesWon = battlesLost = starsGained = starsLost = shipsLost = 0;
    world.removeAll(world.children.toList());
  }
}
