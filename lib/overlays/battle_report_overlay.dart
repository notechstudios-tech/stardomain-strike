import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class BattleReportOverlay extends StatelessWidget {
  final StardomainGame game;
  const BattleReportOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: screenW / 3,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xE6060B1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x66FFFFFF), width: 1),
          boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 16)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BATTLE REPORT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                decoration: TextDecoration.none,
              ),
            ),
            const Divider(color: Color(0x44FFFFFF), height: 16, thickness: 1),
            _StatRow('Battles Won',  game.battlesWon.toString(),  const Color(0xFF66BB6A)),
            _StatRow('Battles Lost', game.battlesLost.toString(), const Color(0xFFEF5350)),
            _StatRow('Stars Gained', game.starsGained.toString(), const Color(0xFF42A5F5)),
            _StatRow('Stars Lost',   game.starsLost.toString(),   const Color(0xFFFFB74D)),
            _StatRow('Ships Lost',   game.shipsLost.toString(),   const Color(0xFFB0BEC5)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: game.dismissBattleReport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 10,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
