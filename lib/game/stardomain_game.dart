import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/star_component.dart';
import '../models/star_config.dart';
import '../services/ads_service.dart';

enum GameState { menu, playing, transitioning }

class StardomainGame extends FlameGame {
  static const String overlayMenu = 'menu';
  static const String overlayMessage = 'message';
  static const String overlayHud = 'hud';
  static const String overlayStarInfo = 'starInfo';

  static const double universeWidth = 3200;
  static const double universeHeight = 1600;
  static const int neutralStarCount = 160;

  static const double playerStarX = 800;
  static const double playerStarY = 800;
  static const double enemyStarX = 2400;
  static const double enemyStarY = 800;

  final AdsService adsService = AdsService();

  GameState _state = GameState.menu;
  String messageText = '';

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
    final maxX = (universeWidth - size.x / z).clamp(0.0, universeWidth);
    final maxY = (universeHeight - size.y / z).clamp(0.0, universeHeight);
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
    final w = size.x;
    final h = size.y;

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
    _state = GameState.transitioning;
    camera.viewfinder.zoom = 1.0;
    _buildUniverse();
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
  }

  // ─── Universe ─────────────────────────────────────────────────────────────

  void _buildUniverse() {
    final rand = math.Random();

    for (final (name, count, scale) in <(String, int, double)>[
      ('nebula_red', 3, 6.0),
      ('nebula_blue', 4, 6.0),
    ]) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        world.add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * universeWidth, rand.nextDouble() * universeHeight),
          anchor: Anchor.center,
          scale: Vector2.all(scale),
        ));
      }
    }

    final bgSp = _sprites['star_light'];
    if (bgSp != null) {
      for (int i = 0; i < 160; i++) {
        world.add(SpriteComponent(
          sprite: bgSp,
          position: Vector2(rand.nextDouble() * universeWidth, rand.nextDouble() * universeHeight),
          anchor: Anchor.center,
          scale: Vector2.all(1.5),
        ));
      }
    }

    final n = neutralStarCount;
    _spawnNeutralStars('star_large', StarSize.large, (n * 0.15).round(), rand);
    _spawnNeutralStars('star_medium', StarSize.medium, (n * 0.35).round(), rand);
    _spawnNeutralStars('star_light', StarSize.light, n - (n * 0.15).round() - (n * 0.35).round(), rand);

    _spawnOccupiedStar(
      x: playerStarX, y: playerStarY,
      owner: 'player', enemySprite: 'enemy_blue',
      ships: 10, resources: 5, defence: 1,
    );
    _spawnOccupiedStar(
      x: enemyStarX, y: enemyStarY,
      owner: 'enemy_red', enemySprite: 'enemy_red',
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
      do {
        x = rand.nextDouble() * (universeWidth - 100) + 50;
        y = rand.nextDouble() * (universeHeight - 100) + 50;
      } while (_tooCloseToHome(x, y));

      final star = StarComponent(
        config: StarConfig(
          size: sz, x: x, y: y,
          ships: _randomShips(rand),
          resources: _randomResources(rand),
          defence: _randomDefence(rand),
        ),
        sprite: sp,
      )
        ..position = Vector2(x, y)
        ..scale = Vector2.all(scale);
      _stars.add(star);
      world.add(star);
    }
  }

  void _spawnOccupiedStar({
    required double x, required double y,
    required String owner, required String enemySprite,
    required int ships, required int resources, required int defence,
  }) {
    final starSp = _sprites['star_large'];
    final iconSp = _sprites[enemySprite];
    if (starSp == null || iconSp == null) return;

    world.add(SpriteComponent(
      sprite: starSp,
      position: Vector2(x, y),
      anchor: Anchor.center,
      scale: Vector2.all(4.5),
    ));

    final star = StarComponent(
      config: StarConfig(
        size: StarSize.large, x: x, y: y, owner: owner,
        ships: ships, resources: resources, defence: defence,
      ),
      sprite: iconSp,
    )
      ..position = Vector2(x, y)
      ..scale = Vector2.all(3.0);
    _stars.add(star);
    world.add(star);
  }

  bool _tooCloseToHome(double x, double y) {
    const minDist = 150.0;
    final dpx = x - playerStarX, dpy = y - playerStarY;
    final dex = x - enemyStarX, dey = y - enemyStarY;
    return (dpx * dpx + dpy * dpy) < minDist * minDist ||
        (dex * dex + dey * dey) < minDist * minDist;
  }

  // ─── Random seeding ───────────────────────────────────────────────────────

  int _randomResources(math.Random rand) {
    final r = rand.nextDouble();
    if (r < 0.80) return 1;
    if (r < 0.95) return 2;
    return 3;
  }

  int _randomDefence(math.Random rand) {
    final r = rand.nextDouble();
    if (r < 0.80) return 1;
    if (r < 0.95) return 2;
    return 3;
  }

  int _randomShips(math.Random rand) => rand.nextInt(5) + 1;

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
    _selector = null;
    selectedStar = null;
    world.removeAll(world.children.toList());
  }
}
