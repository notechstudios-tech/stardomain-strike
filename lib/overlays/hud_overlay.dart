import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class HudOverlay extends StatefulWidget {
  final StardomainGame game;
  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  @override
  void initState() {
    super.initState();
    widget.game.onHudChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.game.onHudChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: fleet and star totals + auto-move
          Row(
            children: [
              _HudChip('Ships: ${game.totalPlayerShips}'),
              const SizedBox(width: 12),
              _HudChip('Stars: ${game.totalPlayerStars}'),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: game.autoMove,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF64B5F6)),
                  ),
                  child: const Text(
                    'AUTO-MOVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Right: turn counter + end turn button
          Row(
            children: [
              _HudChip('Turn: ${game.currentTurn}'),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: game.endTurn,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: const Text(
                    'END TURN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String text;
  const _HudChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
    );
  }
}
