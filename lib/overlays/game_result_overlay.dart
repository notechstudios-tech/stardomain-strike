import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class GameResultOverlay extends StatelessWidget {
  final StardomainGame game;
  const GameResultOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final result = game.gameResult;
    if (result == null) return const SizedBox.shrink();

    final isVictory = result == WinResult.playerElimination ||
                      result == WinResult.playerConquest    ||
                      result == WinResult.playerDominance;

    final titleText  = isVictory ? 'YOU WIN!' : 'DEFEAT';
    final titleColor = isVictory ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    final bodyText = switch (result) {
      WinResult.playerElimination =>
          'All enemy forces have been\ndestroyed!',
      WinResult.playerConquest =>
          'You have conquered the galaxy!',
      WinResult.playerDominance =>
          'Your Opponent bows to your might\nand surrenders!',
      WinResult.enemyConquest =>
          'The enemy has conquered\nthe galaxy.',
      WinResult.playerDefeated =>
          'Your last star has fallen.',
    };

    return Container(
      color: const Color(0xCC000000),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xF0060B1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: titleColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [BoxShadow(color: titleColor.withValues(alpha: 0.15), blurRadius: 32)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleText,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                bodyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 15,
                  height: 1.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: game.backToMenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: const Text(
                    'PLAY AGAIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
