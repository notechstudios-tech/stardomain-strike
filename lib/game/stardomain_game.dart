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

  static const double universeSize = 3200;

  final AdsService adsService = AdsService();

  GameState _state = GameState.menu;
  int currentLevel = 1;
  String messageText = '';

  late LevelConfig _levelConfig;
  final List<StarComponent> _stars = [];
  StarComponent? _selectedStar;
  SpriteComponent? _selector;

  final Map<String, Sprite> _sprites = {};

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  void Function(String)? onMessageChanged;

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
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

  Sprite? getSprite(String name) => _sprites[name];

  // ─── Menu ─────────────────────────────────────────────────────────────────

  void _showMenu() {
    _state = GameState.menu;
    _stopMusic();
    _clearAll();
    _spawnMenuStarfield();
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
      ('star_light', 128, 1.0),
      ('star_medium', 64, 1.5),
      ('star_large', 32, 2.0),
      ('nebula_red', 1, 3.0),
      ('nebula_blue', 2, 3.0),
    ];

    for (final (name, count, scale) in entries) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        add(SpriteComponent(
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

    camera.moveTo(Vector2.zero());

    _showMessage(_levelConfig.text);
    await Future.delayed(const Duration(seconds: 2));
    overlays.remove(overlayMessage);
    _state = GameState.playing;
  }

  void _buildUniverse() {
    final rand = math.Random();

    // Background decoration — non-interactive
    final bgEntries = <(String, int, double)>[
      ('star_light', 128, 1.0),
      ('nebula_red', 1, 3.0),
      ('nebula_blue', 2, 3.0),
    ];
    for (final (name, count, scale) in bgEntries) {
      final sp = _sprites[name];
      if (sp == null) continue;
      for (int i = 0; i < count; i++) {
        add(SpriteComponent(
          sprite: sp,
          position: Vector2(rand.nextDouble() * universeSize, rand.nextDouble() * universeSize),
          anchor: Anchor.center,
          scale: Vector2.all(scale),
        ));
      }
    }

    // Playable stars
    final count = _levelConfig.starCount;
    final lightCount = (count * 0.5).round();
    final mediumCount = (count * 0.35).round();
    final largeCount = count - lightCount - mediumCount;

    _spawnStars('star_medium', StarSize.medium, mediumCount, rand);
    _spawnStars('star_large', StarSize.large, largeCount, rand);
    _spawnStars('star_light', StarSize.light, lightCount, rand);
  }

  void _spawnStars(String spriteName, StarSize sz, int count, math.Random rand) {
    final sp = _sprites[spriteName];
    if (sp == null) return;

    final scale = switch (sz) {
      StarSize.light => 1.0,
      StarSize.medium => 1.5,
      StarSize.large => 2.0,
    };

    for (int i = 0; i < count; i++) {
      final x = rand.nextDouble() * (universeSize - 80) + 40;
      final y = rand.nextDouble() * (universeSize - 80) + 40;
      final config = StarConfig(size: sz, x: x, y: y);
      final star = StarComponent(config: config, sprite: sp)
        ..position = Vector2(x, y)
        ..scale = Vector2.all(scale);
      _stars.add(star);
      add(star);
    }
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (_state != GameState.playing) return;
    final pos = camera.globalToLocal(event.localPosition);

    for (final star in _stars) {
      if (!star.isMounted) continue;
      if (star.containsPoint(pos)) {
        _selectStar(star);
        return;
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    camera.viewfinder.position = camera.viewfinder.position - event.localDelta;
  }

  void _selectStar(StarComponent star) {
    _sfx.play(AssetSource('sound/select.wav'));
    _selector?.removeFromParent();

    final selSp = _sprites['select_green'];
    if (selSp != null) {
      _selector = SpriteComponent(
        sprite: selSp,
        position: star.position,
        anchor: Anchor.center,
        scale: star.scale,
      );
      add(_selector!);
    }

    _selectedStar?.isSelected = false;
    star.isSelected = true;
    _selectedStar = star;
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
    _selectedStar = null;
    _selector = null;
    removeAll(children.toList());
  }
}
