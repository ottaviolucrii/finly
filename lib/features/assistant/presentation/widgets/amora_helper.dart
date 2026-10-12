import 'dart:async';

import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:flutter/material.dart';

/// Amora floating in the corner of Início: a small round button that opens
/// her help. The first time per session she shows the tip of the day in a
/// bubble beside her, which goes away by itself.
class AmoraHelper extends StatefulWidget {
  final AmoraTip tip;
  final VoidCallback onOpen;

  /// How long the bubble stays (tests pass a short one).
  final Duration bubbleTime;

  const AmoraHelper({
    super.key,
    required this.tip,
    required this.onOpen,
    this.bubbleTime = const Duration(seconds: 7),
  });

  /// The bubble shows once per session (not every time Início is shown).
  static bool bubbleShown = false;

  @override
  State<AmoraHelper> createState() => _AmoraHelperState();
}

class _AmoraHelperState extends State<AmoraHelper> {
  bool _bubble = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!AmoraHelper.bubbleShown && widget.tip != amoraIdleTip) {
      AmoraHelper.bubbleShown = true;
      _bubble = true;
      _timer = Timer(widget.bubbleTime, () {
        if (mounted) setState(() => _bubble = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open() {
    _timer?.cancel();
    if (_bubble) setState(() => _bubble = false);
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: !_bubble
              ? const SizedBox.shrink()
              : GestureDetector(
                  key: const ValueKey('amora-bubble'),
                  onTap: _open,
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      margin: const EdgeInsets.only(right: 8, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Text(widget.tip.text, style: text.bodySmall?.copyWith(fontSize: 13, height: 1.35)),
                    ),
                  ),
                ),
        ),
        Semantics(
          button: true,
          label: 'Amora, sua ajudante. Abrir ajuda',
          excludeSemantics: true,
          onTap: _open,
          child: Material(
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            color: Colors.white,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _open,
              child: AmoraAvatar(mood: widget.tip.mood, size: 56, ring: true),
            ),
          ),
        ),
      ],
    );
  }
}
