import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';
import '../models/star_config.dart';

class StarInfoOverlay extends StatefulWidget {
  final StardomainGame game;
  const StarInfoOverlay({super.key, required this.game});

  @override
  State<StarInfoOverlay> createState() => _StarInfoOverlayState();
}

class _StarInfoOverlayState extends State<StarInfoOverlay> {
  @override
  void initState() {
    super.initState();
    widget.game.onStarSelected = (_) { if (mounted) setState(() {}); };
    widget.game.onActionChanged = () { if (mounted) setState(() {}); };
  }

  @override
  void dispose() {
    widget.game.onStarSelected = null;
    widget.game.onActionChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final star = game.selectedStar;
    if (star == null) return const SizedBox.shrink();

    final inTransit = game.shipsInTransitFrom(star);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(210),
          border: Border.all(color: Colors.blue.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatItem(label: 'Ships', value: '${star.ships}'),
                _divider(),
                if (inTransit > 0) ...[
                  _StatItem(
                    label: 'In Transit',
                    value: '$inTransit',
                    valueColor: Colors.orange.shade300,
                  ),
                  _divider(),
                ],
                _StatItem(label: 'Resources', value: '${star.resources}/turn'),
                _divider(),
                _StatItem(label: 'Defence', value: '${star.defence}'),
              ],
            ),
            if (star.specialType == SpecialStarType.wormhole &&
                star.wormholeTarget != null &&
                star.wormholeDiscovered) ...[
              const SizedBox(height: 10),
              _WarpControls(game: game),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.blue.shade800,
        margin: const EdgeInsets.symmetric(horizontal: 20),
      );
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade200,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      );
}

class _WarpControls extends StatelessWidget {
  final StardomainGame game;
  const _WarpControls({required this.game});

  @override
  Widget build(BuildContext context) {
    final ships    = game.shipsToSend;
    final maxShips = game.selectedStar?.ships ?? 0;
    final canWarp  = maxShips > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                'ships',
                style: TextStyle(
                  color: Colors.cyan.shade200,
                  fontSize: 10,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: game.increaseShips,
          child: _arrowBtn('>', ships >= maxShips),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: canWarp ? game.warp : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: canWarp ? const Color(0xFF006064) : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: canWarp ? const Color(0xFF00E5FF) : Colors.grey.shade600,
              ),
            ),
            child: const Text(
              'WARP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _arrowBtn(String label, bool disabled) => Container(
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade900 : Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled ? Colors.grey : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      );
}
