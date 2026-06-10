import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';
import '../services/storage_service.dart';

class MenuOverlay extends StatefulWidget {
  final StardomainGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    StorageService.hasSavedGame().then((v) {
      if (mounted) setState(() => _hasSave = v);
    });
  }

  Future<void> _onContinue() async {
    widget.game.continueGame();
  }

  Future<void> _onNewGame(BuildContext context) async {
    if (_hasSave) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xF0060B1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0x44FFFFFF)),
          ),
          title: const Text(
            'Start New Game?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          content: const Text(
            'Starting a new game will erase your previous save. Are you sure?',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Start New',
                style: TextStyle(
                  color: Color(0xFFEF5350),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    widget.game.startGame();
  }

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand forces the menu to fill the screen (overlays get loose
    // constraints, which would otherwise shrink it to the content and pin it
    // top-left). Full height keeps the Spacers working.
    return SizedBox.expand(
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset('assets/img/menu_title.png', width: 440),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => _onNewGame(context),
                child: Image.asset('assets/img/newgame_button.png', width: 220),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _hasSave ? _onContinue : null,
                child: Opacity(
                  opacity: _hasSave ? 1.0 : 0.35,
                  child: Image.asset(
                    'assets/img/continue_button.png',
                    width: 220,
                  ),
                ),
              ),
              const Spacer(flex: 4),
              // Studio credit at the bottom of the screen.
              const Text(
                'By NoTech Studios  Copyright 2026',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
