import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

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
    widget.game.onStarSelected = (_) {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.game.onStarSelected = null;
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
        child: Row(
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
