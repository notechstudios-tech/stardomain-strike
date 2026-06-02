import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/star_component.dart';
import '../data/levels.dart';
import '../models/level_config.dart';
import '../models/star_config.dart';
import '../services/ads_service.dart';

enum GameState { menu, playing, transitioning }

class StardomainGame extends FlameGame {
  static const String overlayMenu = 'menu';
  static const String overlayMessage = 'message';
  static const String overlayHud = 'hud';
  static const String overlayStarInfo = 'starInfo';

  static const double universeSize = 1600;
  // Player star fixed at left-center, enemy at right-center
  static const double playerStarX = 500;
  static const double playerStarY = 800;
  static const double enemyStarX = 1100;
  static const double enemyStarY = 800;

  final AdsService adsService = AdsService();

  GameState _state = GameState.menu;
  int currentLevel = 1;
  String messageText = '';

  late LevelConfig _levelConfig;
  final List<StarComponent> _stars = [];
  SpriteComponent? _selector;

  StarComponent? selectedStar;
  void Function(StarComponent?)? onStarSelected;

  final Map<String, Sprite> _sprites = {};

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  void Function(String)? onMessageChanged;

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
      'nebula_red', 'nebula_blue',
      'select_green',
      'enemy_blue', 'enemy_red', 'enemy_grey',
    ];
    for (final name in imageNames) {
      try {
        _sprites[name] = await Sprite.load('img/$name.png');
      } catch (_) {}
    }
  }

  // ─── Input (called from Flutter GestureDetector in main.dart) ────────────

  void handleTap(Vector2 screenPos) {
    if (_state != GameState.playing) return;
    final worldPos = camera.viewfinder.position + screenPos / camera.viewfinder.zoom;

    for (final star in _stars) {
      if (!star.isMounted) continue;
      final dx = worldPos.x - star.position.x;
      final dy = worldPos.y - star.position.y;
      final r = star.radius;
      if (dx * dx + dy * dy <= r * r) {
        _selectStar(star);
        return;
      }
    }
    _deselectStar();
  }

  void handlePanZoom({
    required Vector2 panDelta,
    required double newZoom,
    required Vector2 focal,
  }) {
    if (_state == GameState.menu) return;

    final oldZoom = camera.viewfinder.zoom;

    // Zoom centered on the focal point
    if ((newZoom - oldZoom).abs() > 0.001) {
      camera.viewfinder.position += focal * (1.0 / oldZoom - 1.0 / newZoom);
      camera.viewfinder.zoom = newZoom;
    }

    // Pan (convert screen delta to world units)
    if (panDelta.length2 > 0) {
      camera.viewfinder.position -= panDelta / camera.viewfinder.zoom;
    }

    _clampCamera();
  }

  void _clampCamera() {
    final z = camera.viewfinder.zoom;
    final maxX = (universeSize - size.x / z).clamp(0.0, universeSize);
    final maxY = (universeSize - size.y / z).clamp(0.0, universeSize);
    final pos = camera.viewfinder.position;
    pos.x = pos.x.clamp(0.0, maxX);
    pos.y = pos.y.clamp(0.0, maxY);
    camera.viewfinder.position = pos;
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
    overlays.add(overlayMenu);
    _playMusic('Title_Music.wav');
  }

  void _spawnMenuStarfield() {
    final rand = math.Random();
    final screenW = size.x;
    final screenH = size.y;

    for (final (name, count, scale) in <(String, int, double)>[
      ('star_light', 80, 2.0),
      ('star_medium', 40, 3.0),
      ('star_large', 15, 4.0),
      ('nebula_red', 1, 5.0),
      ('nebula_blue', 2, 5.0),
    ]) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        world.add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * screenW, rand.nextDouble() * screenH),
          anchor: Anchor.center,
          scale: Vector2.all(scale),
        ));
      }
    }
  }

  Future<void> startGame(int level) async {
    currentLevel = level;
    overlays.remove(overlayMenu);
    overlays.add(overlayHud);
    _clearAll();
    await _loadLevel();
  }

  // ─── Level loading ────────────────────────────────────────────────────────

  Future<void> _loadLevel() async {
    if (currentLevel > levels.length) {
      _showMessage('Winner! You beat the game!');
      await Future.delayed(const Duration(seconds: 2));
      _showMenu();
      return;
    }

    _levelConfig = levels[currentLevel - 1];
    _state = GameState.transitioning;
    _clearAll();
    camera.viewfinder.zoom = 1.0;
    _buildUniverse();
    _stopMusic();
    _playMusic('level_music.wav');

    // Start focused on the player's star
    camera.viewfinder.position = Vector2(
      playerStarX - size.x / 2,
      playerStarY - size.y / 2,
    );

    _showMessage(_levelConfig.text);
    await Future.delayed(const Duration(seconds: 2));
    overlays.remove(overlayMessage);
    _state = GameState.playing;
  }

  void _buildUniverse() {
    final rand = math.Random();

    // Background nebulas
    for (final (name, count, scale) in <(String, int, double)>[
      ('nebula_red', 2, 6.0),
      ('nebula_blue', 3, 6.0),
    ]) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        world.add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * universeSize, rand.nextDouble() * universeSize),
          anchor: Anchor.center,
          scale: Vector2.all(scale),
        ));
      }
    }

    // Neutral stars (background dots for atmosphere + interactive ones)
    final bgSp = _sprites['star_light'];
    if (bgSp != null) {
      for (int i = 0; i < 100; i++) {
        world.add(SpriteComponent(
          sprite: bgSp,
          position: Vector2(rand.nextDouble() * universeSize, rand.nextDouble() * universeSize),
          anchor: Anchor.center,
          scale: Vector2.all(1.5),
        ));
      }
    }

    // Interactive neutral stars
    final neutralCount = _levelConfig.neutralStarCount;
    final largeCount = (neutralCount * 0.15).round();
    final mediumCount = (neutralCount * 0.35).round();
    final lightCount = neutralCount - largeCount - mediumCount;

    _spawnNeutralStars('star_large', StarSize.large, largeCount, rand);
    _spawnNeutralStars('star_medium', StarSize.medium, mediumCount, rand);
    _spawnNeutralStars('star_light', StarSize.light, lightCount, rand);

    // Player's home star (blue)
    _spawnOccupiedStar(
      x: playerStarX, y: playerStarY,
      owner: 'player',
      enemySprite: 'enemy_blue',
      ships: 10, resources: 5, defence: 1,
    );

    // Enemy's home star (red)
    _spawnOccupiedStar(
      x: enemyStarX, y: enemyStarY,
      owner: 'enemy_red',
      enemySprite: 'enemy_red',
      ships: 10, resources: 5, defence: 1,
    );
  }

  void _spawnNeutralStars(String spriteName, StarSize sz, int count, math.Random rand) {
    final sp = _sprites[spriteName];
    if (sp == null) return;
    final scale = switch (sz) {
      StarSize.light => 2.0,
      StarSize.medium => 3.0,
      StarSize.large => 4.0,
    };
    for (int i = 0; i < count; i++) {
      double x, y;
      // Keep neutral stars away from the fixed home stars
      do {
        x = rand.nextDouble() * (universeSize - 100) + 50;
        y = rand.nextDouble() * (universeSize - 100) + 50;
      } while (_tooCloseToHome(x, y));

      final resources = rand.nextInt(6) + 2; // 2–7
      final star = StarComponent(
        config: StarConfig(size: sz, x: x, y: y, resources: resources),
        sprite: sp,
      )
        ..position = Vector2(x, y)
        ..scale = Vector2.all(scale);
      _stars.add(star);
      world.add(star);
    }
  }

  void _spawnOccupiedStar({
    required double x,
    required double y,
    required String owner,
    required String enemySprite,
    required int ships,
    required int resources,
    required int defence,
  }) {
    final starSp = _sprites['star_large'];
    final iconSp = _sprites[enemySprite];
    if (starSp == null || iconSp == null) return;

    // Star body underneath
    world.add(SpriteComponent(
      sprite: starSp,
      position: Vector2(x, y),
      anchor: Anchor.center,
      scale: Vector2.all(4.5),
    ));

    // Owner icon on top (slightly smaller so star peeks out)
    final star = StarComponent(
      config: StarConfig(
        size: StarSize.large,
        x: x, y: y,
        owner: owner,
        ships: ships,
        resources: resources,
        defence: defence,
      ),
      sprite: iconSp,
    )
      ..position = Vector2(x, y)
      ..scale = Vector2.all(3.0);
    _stars.add(star);
    world.add(star);
  }

  bool _tooCloseToHome(double x, double y) {
    const minDist = 120.0;
    final dpx = x - playerStarX, dpy = y - playerStarY;
    final dex = x - enemyStarX, dey = y - enemyStarY;
    return (dpx * dpx + dpy * dpy) < minDist * minDist ||
        (dex * dex + dey * dey) < minDist * minDist;
  }

  // ─── Selection ────────────────────────────────────────────────────────────

  void _selectStar(StarComponent star) {
    _sfx.play(AssetSource('sound/select.wav'));
    _selector?.removeFromParent();
    _selector = null;

    final selSp = _sprites['select_green'];
    if (selSp != null) {
      _selector = SpriteComponent(
        sprite: selSp,
        position: star.position,
        anchor: Anchor.center,
        scale: star.scale * 1.5,
      );
      world.add(_selector!);
    }

    selectedStar = star;
    onStarSelected?.call(star);

    if (star.config.owner == 'player') {
      overlays.add(overlayStarInfo);
    } else {
      overlays.remove(overlayStarInfo);
    }
  }

  void _deselectStar() {
    _selector?.removeFromParent();
    _selector = null;
    selectedStar = null;
    onStarSelected?.call(null);
    overlays.remove(overlayStarInfo);
  }

  // ─── Message overlay ──────────────────────────────────────────────────────

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
    _selector = null;
    selectedStar = null;
    world.removeAll(world.children.toList());
  }
}
