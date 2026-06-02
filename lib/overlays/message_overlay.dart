import 'package:flutter/material.dart';
import '../game/stardomain_game.dart';

class MessageOverlay extends StatefulWidget {
  final StardomainGame game;
  const MessageOverlay({super.key, required this.game});

  @override
  State<MessageOverlay> createState() => _MessageOverlayState();
}

class _MessageOverlayState extends State<MessageOverlay> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = widget.game.messageText;
    widget.game.onMessageChanged = (text) {
      if (mounted) setState(() => _text = text);
    };
  }

  @override
  void dispose() {
    widget.game.onMessageChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Text(
        _text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
          shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
        ),
      ),
    );
  }
}
