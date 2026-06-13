import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';
import '../models/technology.dart';

/// Technology panel opened from the HUD. Spend tech currency (1 per player star
/// per turn) on per-star upgrades (defence / production, max 3 each) or one-off
/// empire-wide abilities. Anchored to the right so the map stays tappable —
/// selecting a star live-updates the per-star section.
class TechMenuOverlay extends StatefulWidget {
  final StardomainGame game;
  const TechMenuOverlay({super.key, required this.game});

  @override
  State<TechMenuOverlay> createState() => _TechMenuOverlayState();
}

class _TechMenuOverlayState extends State<TechMenuOverlay> {
  StardomainGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    game.onTechChanged = () { if (mounted) setState(() {}); };
  }

  @override
  void dispose() {
    game.onTechChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {}, // swallow taps on the panel; map taps pass through
        child: Container(
          width: screenW * 0.46,
          margin: const EdgeInsets.fromLTRB(0, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xF0060B1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x6664B5F6), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0xAA000000), blurRadius: 24),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const Divider(height: 1, color: Color(0x2264B5F6)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _sectionLabel('SELECTED STAR'),
                    const SizedBox(height: 8),
                    _selectedStarSection(),
                    const SizedBox(height: 20),
                    _sectionLabel('EMPIRE ABILITIES'),
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Bought once each. Greyed out if already owned — including '
                        'abilities discovered at stars.',
                        style: TextStyle(
                          color: Color(0xFF8A99A8),
                          fontSize: 11,
                          height: 1.35,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    ...Technology.values.map(_abilityRow),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          const Icon(Icons.science, color: Color(0xFF64B5F6), size: 22),
          const SizedBox(width: 8),
          const Text(
            'TECHNOLOGY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2137),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF64B5F6)),
            ),
            child: Text(
              '${game.techPoints} tech',
              style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: game.hideTechMenu,
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close, color: Colors.white70, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF64B5F6),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          decoration: TextDecoration.none,
        ),
      );

  Widget _selectedStarSection() {
    final star = game.techUpgradeStar;
    if (star == null) {
      return const Text(
        'Tap one of your stars on the map to upgrade its defence or production.',
        style: TextStyle(
          color: Color(0xFFB0BEC5),
          fontSize: 13,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _upgradeRow(
          label: 'Defence',
          current: star.defence,
          bought: star.techDefence,
          cost: StardomainGame.techCostDefence,
          canBuy: game.canBuyStarDefence,
          onBuy: () => game.buyStarDefence(),
        ),
        const SizedBox(height: 8),
        _upgradeRow(
          label: 'Production',
          current: star.resources,
          suffix: '/turn',
          bought: star.techProduction,
          cost: StardomainGame.techCostProduction,
          canBuy: game.canBuyStarProduction,
          onBuy: () => game.buyStarProduction(),
        ),
      ],
    );
  }

  Widget _upgradeRow({
    required String label,
    required int current,
    String suffix = '',
    required int bought,
    required int cost,
    required bool canBuy,
    required VoidCallback onBuy,
  }) {
    final maxed = bought >= StardomainGame.techMaxPerStar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $current$suffix',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  'Upgraded $bought / ${StardomainGame.techMaxPerStar}',
                  style: const TextStyle(
                    color: Color(0xFF8A99A8),
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          maxed
              ? _tag('MAX', const Color(0xFF455A64))
              : _buyButton('+1   •   $cost', canBuy, onBuy),
        ],
      ),
    );
  }

  Widget _abilityRow(Technology t) {
    final owned = game.hasTech(t);
    final canBuy = game.canBuyAbility(t);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: owned ? const Color(0xFF10161E) : const Color(0xFF0A1626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: owned ? const Color(0x22FFFFFF) : const Color(0x33FFFFFF),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.displayName,
                  style: TextStyle(
                    color: owned ? const Color(0xFF6B7884) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.description,
                  style: TextStyle(
                    color: owned
                        ? const Color(0xFF55606B)
                        : const Color(0xFF9FB0BE),
                    fontSize: 11,
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          owned
              ? _tag('OWNED', const Color(0xFF37474F))
              : _buyButton(
                  '${StardomainGame.techCostAbility}',
                  canBuy,
                  () => game.buyAbility(t),
                ),
        ],
      ),
    );
  }

  Widget _buyButton(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF1565C0) : const Color(0xFF263238),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? const Color(0xFF64B5F6) : const Color(0xFF3A474F),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : const Color(0xFF6B7884),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCFD8DC),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            decoration: TextDecoration.none,
          ),
        ),
      );
}
