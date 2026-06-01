import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/stardomain_game.dart';
import 'overlays/menu_overlay.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/message_overlay.dart';

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
      home: GameWidget<StardomainGame>(
        game: game,
        overlayBuilderMap: {
          StardomainGame.overlayMenu: (_, g) => MenuOverlay(game: g),
          StardomainGame.overlayMessage: (_, g) => MessageOverlay(game: g),
          StardomainGame.overlayHud: (_, g) => HudOverlay(game: g),
        },
      ),
    );
  }
}
