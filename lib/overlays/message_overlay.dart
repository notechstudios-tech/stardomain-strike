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
    return Center(
      child: Text(
        _text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
          shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
        ),
      ),
    );
  }
}
