import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import '../components/star_component.dart';
import '../data/levels.dart';
import '../models/level_config.dart';
import '../models/star_config.dart';
import '../services/ads_service.dart';

enum GameState { menu, playing, transitioning }

class StardomainGame extends FlameGame with TapCallbacks, DragCallbacks {
  static const String overlayMenu = 'menu';
  static const String overlayMessage = 'message';
  static const String overlayHud = 'hud';

  static const double universeSize = 1600;

  final AdsService adsService = AdsService();

  GameState _state = GameState.menu;
  int currentLevel = 1;
  String messageText = '';

  late LevelConfig _levelConfig;
  final List<StarComponent> _stars = [];
  SpriteComponent? _selector;

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
      'menu_title', 'continue_button', 'newgame_button',
      'select_green',
      'enemy_blue', 'enemy_red', 'enemy_grey',
    ];
    for (final name in imageNames) {
      try {
        _sprites[name] = await Sprite.load('img/$name.png');
      } catch (_) {}
    }
  }

  // ─── Menu ─────────────────────────────────────────────────────────────────

  void _showMenu() {
    _state = GameState.menu;
    _stopMusic();
    _clearAll();
    _spawnMenuStarfield();
    camera.viewfinder.position = Vector2.zero();
    overlays.remove(overlayHud);
    overlays.remove(overlayMessage);
    overlays.add(overlayMenu);
    _playMusic('Title_Music.wav');
  }

  void _spawnMenuStarfield() {
    final rand = math.Random();
    final screenW = size.x;
    final screenH = size.y;

    final entries = <(String, int, double)>[
      ('star_light', 80, 2.0),
      ('star_medium', 40, 3.0),
      ('star_large', 15, 4.0),
      ('nebula_red', 1, 5.0),
      ('nebula_blue', 2, 5.0),
    ];
    for (final (name, count, scale) in entries) {
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
    _buildUniverse();
    _stopMusic();
    _playMusic('level_music.wav');

    camera.viewfinder.position = Vector2(
      universeSize / 2 - size.x / 2,
      universeSize / 2 - size.y / 2,
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

    // Playable stars — mix of neutral and enemy-occupied
    final total = _levelConfig.starCount;
    final enemyCount = (total * _levelConfig.enemyFraction).round();
    final neutralCount = total - enemyCount;

    final lightN = (neutralCount * 0.45).round();
    final mediumN = (neutralCount * 0.35).round();
    final largeN = neutralCount - lightN - mediumN;

    _spawnNeutralStars('star_large', StarSize.large, largeN, rand);
    _spawnNeutralStars('star_medium', StarSize.medium, mediumN, rand);
    _spawnNeutralStars('star_light', StarSize.light, lightN, rand);

    // Enemy stars: half red, half blue
    final redCount = enemyCount ~/ 2;
    final blueCount = enemyCount - redCount;
    _spawnEnemyStars('enemy_red', StarSize.large, redCount, rand);
    _spawnEnemyStars('enemy_blue', StarSize.large, blueCount, rand);
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
      final x = rand.nextDouble() * (universeSize - 100) + 50;
      final y = rand.nextDouble() * (universeSize - 100) + 50;
      final star = StarComponent(config: StarConfig(size: sz, x: x, y: y), sprite: sp)
        ..position = Vector2(x, y)
        ..scale = Vector2.all(scale);
      _stars.add(star);
      world.add(star);
    }
  }

  void _spawnEnemyStars(String spriteName, StarSize sz, int count, math.Random rand) {
    final sp = _sprites[spriteName];
    if (sp == null) return;
    for (int i = 0; i < count; i++) {
      final x = rand.nextDouble() * (universeSize - 100) + 50;
      final y = rand.nextDouble() * (universeSize - 100) + 50;
      final star = StarComponent(
        config: StarConfig(size: sz, x: x, y: y, owner: spriteName),
        sprite: sp,
      )
        ..position = Vector2(x, y)
        ..scale = Vector2.all(3.5);
      _stars.add(star);
      world.add(star);
    }
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (_state != GameState.playing) return;
    final worldPos = camera.viewfinder.position + event.localPosition;

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
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_state == GameState.menu) return;
    camera.viewfinder.position -= event.localDelta;
    _clampCamera();
  }

  void _clampCamera() {
    final pos = camera.viewfinder.position;
    pos.x = pos.x.clamp(0.0, universeSize - size.x);
    pos.y = pos.y.clamp(0.0, universeSize - size.y);
    camera.viewfinder.position = pos;
  }

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
        scale: star.scale * 1.4,
      );
      world.add(_selector!);
    }
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
    world.removeAll(world.children.toList());
  }
}
