import 'package:flutter/material.dart';
import '../components/star_component.dart';
import '../game/stardomain_game.dart';

class StarInfoOverlay extends StatefulWidget {
  final StardomainGame game;
  const StarInfoOverlay({super.key, required this.game});

  @override
  State<StarInfoOverlay> createState() => _StarInfoOverlayState();
}

class _StarInfoOverlayState extends State<StarInfoOverlay> {
  StarComponent? _star;

  @override
  void initState() {
    super.initState();
    _star = widget.game.selectedStar;
    widget.game.onStarSelected = (star) {
      if (mounted) setState(() => _star = star);
    };
  }

  @override
  void dispose() {
    widget.game.onStarSelected = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final star = _star;
    if (star == null) return const SizedBox.shrink();

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
            const _Divider(),
            _StatItem(label: 'Resources', value: '${star.resources}/turn'),
            const _Divider(),
            _StatItem(label: 'Defence', value: '${star.defence}'),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
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
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: Colors.blue.shade800,
        margin: const EdgeInsets.symmetric(horizontal: 20),
      );
}
