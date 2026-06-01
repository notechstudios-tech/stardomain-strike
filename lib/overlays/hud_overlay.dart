import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class HudOverlay extends StatelessWidget {
  final StardomainGame game;
  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HudText('Level: ${game.currentLevel}'),
          _HudText('Stardomain Strike'),
        ],
      ),
    );
  }
}

class _HudText extends StatelessWidget {
  final String text;
  const _HudText(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      );
}
