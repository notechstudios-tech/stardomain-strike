import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class MenuOverlay extends StatelessWidget {
  final StardomainGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/img/menu_title.png', width: 520),
            const SizedBox(height: 12),
            const Text(
              'By NoTech Studios  Copyright 2026',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => game.startGame(),
              child: Image.asset('assets/img/continue_button.png', width: 240),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => game.startGame(),
              child: Image.asset('assets/img/newgame_button.png', width: 240),
            ),
          ],
        ),
      ),
    );
  }
}
