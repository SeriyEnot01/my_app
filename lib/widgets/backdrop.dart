import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Dark background with soft coloured glows, behind the main screens.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: C.bg)),
        Positioned(top: -260, right: -180, child: _Glow(size: 680, color: C.accent.withOpacity(.16))),
        Positioned(top: 320, left: -280, child: _Glow(size: 620, color: C.workout.withOpacity(.07))),
        Positioned(bottom: -300, right: 60, child: _Glow(size: 640, color: C.lilac.withOpacity(.08))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
          ),
        ),
      );
}
