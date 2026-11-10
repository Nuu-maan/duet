import 'package:flutter/material.dart';

class Appear extends StatelessWidget {
  const Appear({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => FadeTransition(
        opacity: AlwaysStoppedAnimation(t),
        child: reduced
            ? child
            : Transform.scale(scale: 0.95 + 0.05 * t, child: child),
      ),
    );
  }
}
