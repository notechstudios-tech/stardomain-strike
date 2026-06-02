import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/connection_line.dart';
import '../components/star_component.dart';
import '../models/fleet.dart';
import '../models/star_config.dart';
import '../services/ads_service.dart';

enum GameState { menu, playing, transitioning }

class StardomainGame extends FlameGame {
  static const String overlayMenu    = 'menu';
  static const String overlayMessage = 'message';
  static const String overlayHud     = 'hud';
  static const String overlayStarInfo = 'starInfo';
  static const String overlayAction  = 'action';

  static const double universeWidth  = 3200;
  static const double universeHeight = 1600;
  static const int    neutralStarCount = 160;
  static const double travelSpeed    = 400.0; // world units per turn

  static const double playerStarX = 800;
  static const double playerStarY = 800;
  static const double enemyStarX  = 2400;
  static const double enemyStarY  = 800;

  final AdsService adsService = AdsService();

  GameState _state = GameState.menu;
  int _currentTurn = 1;

  final List<StarComponent> _stars  = [];
  final List<Fleet>         _fleets = [];

  // Selection state
  StarComponent?   _selectedStar;   // player's "from" star
  StarComponent?   _targetStar;     // any "to" star
  SpriteComponent? _ring1;          // ring on _selectedStar
  SpriteComponent? _ring2;          // ring on _targetStar
  ConnectionLine?  _connectionLine;
  int              _shipsToSend = 0;

  final Map<String, Sprite> _sprites = {};
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  String messageText = '';

  // Overlay callbacks
  void Function(String)? onMessageChanged;
  void Function()?       onHudChanged;
  void Function()?       onActionChanged;
  void Function(StarComponent?)? onStarSelected;

  // ─── Public accessors used by overlays ───────────────────────────────────

  int get currentTurn => _currentTurn;

  int get totalPlayerShips => _stars
      .where((s) => s.owner == 'player' && s.isMounted)
      .fold(0, (sum, s) => sum + s.ships);

  int get totalPlayerStars =>
      _stars.where((s) => s.owner == 'player' && s.isMounted).length;

  StarComponent? get selectedStar => _selectedStar;
  StarComponent? get targetStar   => _targetStar;
  int get shipsToSend => _shipsToSend;

  int get distanceInTurns {
    if (_selectedStar == null || _targetStar == null) return 0;
    final dx = _selectedStar!.position.x - _targetStar!.position.x;
    final dy = _selectedStar!.position.y - _targetStar!.position.y;
    return math.max(1, (math.sqrt(dx * dx + dy * dy) / travelSpeed).ceil());
  }

  void increaseShips() {
    if (_selectedStar == null) return;
    if (_shipsToSend < _selectedStar!.ships) {
      _shipsToSend++;
      onActionChanged?.call();
    }
  }

  void decreaseShips() {
    if (_shipsToSend > 1) {
      _shipsToSend--;
      onActionChanged?.call();
    }
  }

  void sendFleet() {
    if (_selectedStar == null || _targetStar == null || _shipsToSend <= 0) return;
    if (_selectedStar!.ships < _shipsToSend) return;

    _selectedStar!.ships -= _shipsToSend;
    _fleets.add(Fleet(
      owner: 'player',
      origin: _selectedStar!,
      destination: _targetStar!,
      ships: _shipsToSend,
      turnsRemaining: distanceInTurns,
    ));

    _sfx.play(AssetSource('sound/select.wav'));
    _deselectAll();
    onHudChanged?.call();
  }

  Future<void> endTurn() async {
    if (_state != GameState.playing) return;
    _state = GameState.transitioning;
    _deselectAll();

    // 1. Player fleets advance
    _advanceFleets('player');

    // 2. Player star production
    for (final s in _stars.where((s) => s.owner == 'player')) {
      s.ships += s.resources;
    }

    // 3. Enemy turn (passive: production + fleet movement)
    for (final s in _stars.where((s) => s.owner != null && s.owner != 'player')) {
      s.ships += s.resources;
    }
    _advanceFleets('enemy_red');
    _advanceFleets('enemy_blue');

    _currentTurn++;
    _state = GameState.playing;
    onHudChanged?.call();
  }

  void _advanceFleets(String owner) {
    final toRemove = <Fleet>[];
    for (final f in _fleets.where((f) => f.owner == owner)) {
      f.turnsRemaining--;
      if (f.turnsRemaining <= 0) {
        _processArrival(f);
        toRemove.add(f);
      }
    }
    _fleets.removeWhere(toRemove.contains);
  }

  void _processArrival(Fleet fleet) {
    final dest = fleet.destination;
    if (dest.owner == fleet.owner) {
      dest.ships += fleet.ships;
    } else if (fleet.ships > dest.ships) {
      dest.ships = fleet.ships - dest.ships;
      dest.owner = fleet.owner;
    } else {
      dest.ships = math.max(0, dest.ships - fleet.ships);
    }
    onHudChanged?.call();
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  void handleTap(Vector2 screenPos) {
    if (_state != GameState.playing) return;
    final worldPos = camera.viewfinder.position + screenPos / camera.viewfinder.zoom;

    for (final star in _stars) {
      if (!star.isMounted) continue;
      final dx = worldPos.x - star.position.x;
      final dy = worldPos.y - star.position.y;
      final r = star.radius;
      if (dx * dx + dy * dy <= r * r) {
        _onStarTapped(star);
        return;
      }
    }
    _deselectAll();
  }

  void _onStarTapped(StarComponent star) {
    if (star.owner == 'player') {
      // Always sets a new "from" star
      _clearConnection();
      _setFirstStar(star);
    } else if (_selectedStar != null) {
      // Second star tapped — set as target
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
        sprite: selSp,
        position: star.position,
        anchor: Anchor.center,
        scale: star.scale * 1.5,
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
        sprite: selSp,
        position: star.position,
        anchor: Anchor.center,
        scale: star.scale * 1.5,
      );
      world.add(_ring2!);
    }

    _connectionLine = ConnectionLine(
      from: _selectedStar!.position.clone(),
      to: star.position.clone(),
    );
    world.add(_connectionLine!);

    _targetStar = star;
    // Clamp ships to send to what the source has
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
    _ring1 = null;
    _ring2 = null;
    _connectionLine = null;
    _selectedStar = null;
    _targetStar = null;
    _shipsToSend = 0;
    overlays.remove(overlayStarInfo);
    overlays.remove(overlayAction);
    onStarSelected?.call(null);
    onActionChanged?.call();
  }

  void handlePanZoom({
    required Vector2 panDelta,
    required double newZoom,
    required Vector2 focal,
  }) {
    if (_state == GameState.menu) return;
    final oldZoom = camera.viewfinder.zoom;
    if ((newZoom - oldZoom).abs() > 0.001) {
      camera.viewfinder.position += focal * (1.0 / oldZoom - 1.0 / newZoom);
      camera.viewfinder.zoom = newZoom;
    }
    if (panDelta.length2 > 0) {
      camera.viewfinder.position -= panDelta / camera.viewfinder.zoom;
    }
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
    const imageNames = [
      'star_light', 'star_medium', 'star_large',
      'nebula_red', 'nebula_blue', 'select_green',
      'enemy_blue', 'enemy_red', 'enemy_grey',
    ];
    for (final name in imageNames) {
      try { _sprites[name] = await Sprite.load('img/$name.png'); } catch (_) {}
    }
  }

  // ─── Menu ─────────────────────────────────────────────────────────────────

  void _showMenu() {
    _state = GameState.menu;
    _stopMusic();
    _clearAll();
    _spawnMenuStarfield();
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = 1.0;
    overlays.remove(overlayHud);
    overlays.remove(overlayMessage);
    overlays.remove(overlayStarInfo);
    overlays.remove(overlayAction);
    overlays.add(overlayMenu);
    _playMusic('Title_Music.wav');
  }

  void _spawnMenuStarfield() {
    final rand = math.Random();
    final w = size.x; final h = size.y;
    for (final (name, count, scale) in <(String, int, double)>[
      ('star_light', 80, 2.0), ('star_medium', 40, 3.0), ('star_large', 15, 4.0),
      ('nebula_red', 1, 5.0),  ('nebula_blue', 2, 5.0),
    ]) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        world.add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * w, rand.nextDouble() * h),
          anchor: Anchor.center,
          scale: Vector2.all(scale),
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
    _fleets.clear();
    _state = GameState.transitioning;
    camera.viewfinder.zoom = 1.0;

    // New random seed every game start
    _buildUniverse(math.Random(DateTime.now().millisecondsSinceEpoch));

    _stopMusic();
    _playMusic('level_music.wav');
    camera.viewfinder.position = Vector2(
      playerStarX - size.x / 2,
      playerStarY - size.y / 2,
    );

    _showMessage('Home Star - Start!');
    await Future.delayed(const Duration(seconds: 2));
    overlays.remove(overlayMessage);
    _state = GameState.playing;
    onHudChanged?.call();
  }

  // ─── Universe ─────────────────────────────────────────────────────────────

  void _buildUniverse(math.Random rand) {
    // Nebulas
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

    // Atmospheric dots
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

    // Neutral interactive stars
    final n = neutralStarCount;
    final largeN  = (n * 0.15).round();
    final mediumN = (n * 0.35).round();
    final lightN  = n - largeN - mediumN;
    _spawnNeutralStars('star_large',  StarSize.large,  largeN,  rand);
    _spawnNeutralStars('star_medium', StarSize.medium, mediumN, rand);
    _spawnNeutralStars('star_light',  StarSize.light,  lightN,  rand);

    // Fixed home stars
    _spawnOccupiedStar(x: playerStarX, y: playerStarY, owner: 'player',    iconKey: 'enemy_blue', ships: 10, resources: 3, defence: 1);
    _spawnOccupiedStar(x: enemyStarX,  y: enemyStarY,  owner: 'enemy_red', iconKey: 'enemy_red',  ships: 10, resources: 3, defence: 1);
  }

  void _spawnNeutralStars(String spriteName, StarSize sz, int count, math.Random rand) {
    final sp = _sprites[spriteName];
    if (sp == null) return;
    final scale = switch (sz) {
      StarSize.light => 2.0, StarSize.medium => 3.0, StarSize.large => 4.0,
    };
    for (int i = 0; i < count; i++) {
      double x, y;
      do {
        x = rand.nextDouble() * (universeWidth  - 100) + 50;
        y = rand.nextDouble() * (universeHeight - 100) + 50;
      } while (_tooCloseToHome(x, y));

      final star = StarComponent(
        config: StarConfig(
          size: sz, x: x, y: y,
          ships:     _randomShips(rand),
          resources: _randomResources(rand),
          defence:   _randomDefence(rand),
        ),
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
      sprite: starSp,
      position: Vector2(x, y),
      anchor: Anchor.center,
      scale: Vector2.all(4.5),
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
    final dpx = x - playerStarX, dpy = y - playerStarY;
    final dex = x - enemyStarX,  dey = y - enemyStarY;
    return (dpx*dpx + dpy*dpy) < d*d || (dex*dex + dey*dey) < d*d;
  }

  // ─── Seeding helpers ──────────────────────────────────────────────────────

  int _randomResources(math.Random r) {
    final v = r.nextDouble();
    if (v < 0.80) return 1;
    if (v < 0.95) return 2;
    return 3;
  }

  int _randomDefence(math.Random r) {
    final v = r.nextDouble();
    if (v < 0.80) return 1;
    if (v < 0.95) return 2;
    return 3;
  }

  int _randomShips(math.Random r) => r.nextInt(5) + 1;

  // ─── Message ──────────────────────────────────────────────────────────────

  void _showMessage(String text) {
    messageText = text;
    onMessageChanged?.call(text);
    overlays.add(overlayMessage);
  }

  // ─── Audio ────────────────────────────────────────────────────────────────

  void _playMusic(String filename) {
    _bgm.setReleaseMode(ReleaseMode.loop);
    _bgm.play(AssetSource('sound/$filename'), volume: 0.6);
  }

  void _stopMusic() => _bgm.stop();

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _clearAll() {
    _stars.clear();
    _ring1 = null; _ring2 = null; _connectionLine = null;
    _selectedStar = null; _targetStar = null; _shipsToSend = 0;
    world.removeAll(world.children.toList());
  }
}
