import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';
import '../models/game_event.dart';

class ReportsOverlay extends StatelessWidget {
  final StardomainGame game;
  const ReportsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final history = game.reportHistory;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: game.hideReports, // tap outside the card closes it
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb taps on the card itself
            child: Container(
              width: screenW * 0.7,
              constraints: const BoxConstraints(maxHeight: 460),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xF0060B1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x55FFFFFF), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'REPORTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      GestureDetector(
                        onTap: game.hideReports,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: const Text(
                            'CLOSE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    color: Color(0x33FFFFFF),
                    height: 18,
                    thickness: 1,
                  ),
                  Flexible(
                    child: history.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'No reports yet.',
                              style: TextStyle(
                                color: Color(0xFF90A4AE),
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: history.length,
                            separatorBuilder: (_, _) => const Divider(
                              color: Color(0x22FFFFFF),
                              height: 14,
                              thickness: 1,
                            ),
                            itemBuilder: (context, i) {
                              // Newest first, starting at the top of the list.
                              final (turn, event) =
                                  history[history.length - 1 - i];
                              return _ReportRow(turn: turn, event: event);
                            },
                          ),
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

class _ReportRow extends StatelessWidget {
  final int turn;
  final GameEvent event;
  const _ReportRow({required this.turn, required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            'Turn $turn',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: TextStyle(
                  color: event.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                event.detail,
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 12,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
