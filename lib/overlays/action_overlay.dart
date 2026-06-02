import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class ActionOverlay extends StatefulWidget {
  final StardomainGame game;
  const ActionOverlay({super.key, required this.game});

  @override
  State<ActionOverlay> createState() => _ActionOverlayState();
}

class _ActionOverlayState extends State<ActionOverlay> {
  @override
  void initState() {
    super.initState();
    widget.game.onActionChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.game.onActionChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final turns = game.distanceInTurns;
    final ships = game.shipsToSend;
    final maxShips = game.selectedStar?.ships ?? 0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(210),
          border: Border.all(color: Colors.green.shade400, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distance
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$turns',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                ),
                Text('turns', style: TextStyle(color: Colors.green.shade200,
                    fontSize: 11, decoration: TextDecoration.none)),
              ],
            ),
            _divider(),
            // Ship selector
            GestureDetector(
              onTap: game.decreaseShips,
              child: _arrowBtn('<', ships <= 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$ships',
                    style: const TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                  ),
                  Text('ships', style: TextStyle(color: Colors.green.shade200,
                      fontSize: 11, decoration: TextDecoration.none)),
                ],
              ),
            ),
            GestureDetector(
              onTap: game.increaseShips,
              child: _arrowBtn('>', ships >= maxShips),
            ),
            _divider(),
            // Send button
            GestureDetector(
              onTap: maxShips > 0 ? game.sendFleet : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: maxShips > 0 ? Colors.green.shade700 : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: maxShips > 0 ? Colors.green.shade300 : Colors.grey.shade600,
                  ),
                ),
                child: const Text(
                  'SEND',
                  style: TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrowBtn(String label, bool disabled) {
    return Container(
      width: 32, height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade900 : Colors.white12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: disabled ? Colors.grey : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 36,
    color: Colors.green.shade800,
    margin: const EdgeInsets.symmetric(horizontal: 16),
  );
}
