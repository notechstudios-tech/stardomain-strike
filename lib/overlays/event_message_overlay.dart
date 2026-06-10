import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class EventMessageOverlay extends StatelessWidget {
  final StardomainGame game;
  const EventMessageOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final event = game.currentEvent;
    if (event == null) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;

    // Whole screen is a tap target so a tap anywhere advances to the next star.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: game.advanceEvent,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: screenW * 0.62,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xF0060B1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: event.accentColor.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: event.accentColor.withValues(alpha: 0.2),
                blurRadius: 24,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: event.accentColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                event.detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 17,
                  height: 1.6,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tap to continue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 13,
                  letterSpacing: 1.0,
                  fontStyle: FontStyle.italic,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
