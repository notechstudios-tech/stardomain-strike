import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

/// In-game options menu opened from the HUD. Lets the player restart the game
/// and toggle the "Disable Battles" setting (which falls back to the plain
/// per-star battle summary reports instead of the animated battle scenes).
class GameMenuOverlay extends StatefulWidget {
  final StardomainGame game;
  const GameMenuOverlay({super.key, required this.game});

  @override
  State<GameMenuOverlay> createState() => _GameMenuOverlayState();
}

class _GameMenuOverlayState extends State<GameMenuOverlay> {
  late bool _battlesDisabled = widget.game.battlesDisabled;

  Future<void> _onRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF0060B1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0x44FFFFFF)),
        ),
        title: const Text(
          'Restart Game?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
        content: const Text(
          'Restarting will abandon your current game and start a new universe. '
          'Are you sure?',
          style: TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Restart',
              style: TextStyle(
                color: Color(0xFFEF5350),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.game.restartGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    // Tap on the dim backdrop (outside the panel) closes the menu.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.game.hideGameMenu,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // swallow taps inside the panel
            child: Container(
              width: screenW * 0.5,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xF0060B1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x66FFFFFF), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0xAA000000), blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MENU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Disable Battles checkbox row
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _battlesDisabled = !_battlesDisabled);
                      widget.game.setBattlesDisabled(_battlesDisabled);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          _Checkbox(checked: _battlesDisabled),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Disable Battles',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 36, top: 2, bottom: 6),
                    child: Text(
                      'Skip the animated ship battles and show the star battle '
                      'summary report instead.',
                      style: TextStyle(
                        color: Color(0xFF8A99A8),
                        fontSize: 12,
                        height: 1.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _MenuButton(
                    label: 'RESTART',
                    color: const Color(0xFFB71C1C),
                    borderColor: const Color(0xFFEF5350),
                    onTap: _onRestart,
                  ),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: 'RESUME',
                    color: const Color(0xFF1565C0),
                    borderColor: const Color(0xFF64B5F6),
                    onTap: widget.game.hideGameMenu,
                  ),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: 'QUIT',
                    color: const Color(0xFF37474F),
                    borderColor: const Color(0xFF90A4AE),
                    onTap: widget.game.backToMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? const Color(0xFF1565C0) : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: checked ? const Color(0xFF64B5F6) : Colors.white54,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  const _MenuButton({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
