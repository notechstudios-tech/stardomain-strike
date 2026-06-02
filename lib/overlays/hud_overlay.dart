import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class HudOverlay extends StatelessWidget {
  final StardomainGame game;
  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(width: 120), // placeholder left
          SizedBox(width: 120), // placeholder right
        ],
      ),
    );
  }
}
