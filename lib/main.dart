import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/stardomain_game.dart';
import 'overlays/battle_report_overlay.dart';
import 'overlays/event_message_overlay.dart';
import 'overlays/game_result_overlay.dart';
import 'overlays/menu_overlay.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/message_overlay.dart';
import 'overlays/star_info_overlay.dart';
import 'overlays/action_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const StardomainApp());
}

class StardomainApp extends StatelessWidget {
  const StardomainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = StardomainGame();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _InputWrapper(game: game),
    );
  }
}

class _InputWrapper extends StatefulWidget {
  final StardomainGame game;
  const _InputWrapper({required this.game});
  @override
  State<_InputWrapper> createState() => _InputWrapperState();
}

class _InputWrapperState extends State<_InputWrapper> {
  double _startZoom = 1.0;
  Offset _startFocal = Offset.zero;
  Offset _lastFocal = Offset.zero;
  bool _moved = false;

  StardomainGame get _game => widget.game;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (d) {
        _startZoom = _game.camera.viewfinder.zoom;
        _startFocal = d.localFocalPoint;
        _lastFocal = d.localFocalPoint;
        _moved = false;
      },
      onScaleUpdate: (d) {
        final totalDelta = d.localFocalPoint - _startFocal;
        if (totalDelta.distance > 8 || (d.scale - 1.0).abs() > 0.04) _moved = true;

        final panDelta = d.localFocalPoint - _lastFocal;
        _lastFocal = d.localFocalPoint;

        _game.handlePanZoom(
          panDelta: Vector2(panDelta.dx, panDelta.dy),
          newZoom: (_startZoom * d.scale).clamp(0.3, 4.0),
          focal: Vector2(d.localFocalPoint.dx, d.localFocalPoint.dy),
        );
      },
      onScaleEnd: (_) {
        if (!_moved) {
          _game.handleTap(Vector2(_startFocal.dx, _startFocal.dy));
        }
        _moved = false;
      },
      child: GameWidget<StardomainGame>(
        game: _game,
        overlayBuilderMap: {
          StardomainGame.overlayMenu:         (_, g) => MenuOverlay(game: g),
          StardomainGame.overlayMessage:      (_, g) => MessageOverlay(game: g),
          StardomainGame.overlayHud:          (_, g) => HudOverlay(game: g),
          StardomainGame.overlayStarInfo:     (_, g) => StarInfoOverlay(game: g),
          StardomainGame.overlayAction:       (_, g) => ActionOverlay(game: g),
          StardomainGame.overlayBattleReport: (_, g) => BattleReportOverlay(game: g),
          StardomainGame.overlayGameResult:   (_, g) => GameResultOverlay(game: g),
          StardomainGame.overlayEvent:        (_, g) => EventMessageOverlay(game: g),
        },
      ),
    );
  }
}
