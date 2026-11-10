import 'package:flutter/material.dart';

import 'theme.dart';

class PlayCard extends StatefulWidget {
  const PlayCard({
    super.key,
    required this.child,
    this.colorIndex = 0,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final int colorIndex;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  State<PlayCard> createState() => _PlayCardState();
}

class _PlayCardState extends State<PlayCard> {
  bool _pressed = false;

  void _press(bool value) {
    if (widget.onTap != null) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    final color = playful.card(widget.colorIndex);
    final radius = BorderRadius.circular(28);
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedScale(
          scale: _pressed && !still ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.ease,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(color, theme.colorScheme.shadow, 0.35),
              borderRadius: radius,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
                child: Padding(
                  padding: widget.padding,
                  child: IconTheme.merge(
                    data: IconThemeData(color: playful.onCard),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: playful.onCard),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
