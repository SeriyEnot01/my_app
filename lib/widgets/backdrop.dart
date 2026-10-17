import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/theme.dart';

/// Background of the main screens: theme colour or picture (the theme's own or the user's),
/// three soft glows and the theme's ornament (petals, grid, embers, neon, mist).
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final themes = ThemeScope.of(context);
    final p = C.p;
    final custom = C.customBg;
    final hasPicture = custom != null || p.bgAsset != null;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: p.bg)),
        if (hasPicture)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: _Picture(
                  key: ValueKey(custom ?? p.bgAsset),
                  file: custom,
                  asset: p.bgAsset,
                  blur: themes.blur(p.id),
                  dim: themes.dim(p.id),
                ),
              ),
            ),
          ),
        if (!hasPicture) ...[
          Positioned(top: -260, right: -180, child: _Glow(size: 680, color: p.glows[0])),
          Positioned(top: 320, left: -280, child: _Glow(size: 620, color: p.glows[1])),
          Positioned(bottom: -300, right: 60, child: _Glow(size: 640, color: p.glows[2])),
        ],
        if (p.decor != Decor.none)
          Positioned.fill(
            child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _DecorPainter(p)))),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// The background picture: cover-fitted, optionally blurred, darkened towards the bottom
/// so text on the translucent cards stays readable.
class _Picture extends StatelessWidget {
  const _Picture({super.key, this.file, this.asset, required this.blur, required this.dim});
  final String? file;
  final String? asset;
  final double blur;
  final double dim;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = MediaQuery.sizeOf(context);
    // decode at screen size, not the photo's full resolution
    final cacheW = (math.max(size.width, size.height * 16 / 9) * dpr).clamp(640, 2560).toInt();
    Widget img = file != null
        ? Image.file(File(file!), fit: BoxFit.cover, cacheWidth: cacheW, gaplessPlayback: true, errorBuilder: _fallback)
        : Image.asset(asset!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: _fallback);
    if (blur > .3) {
      img = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.mirror),
        child: img,
      );
    }
    final bg = C.bg;
    final d = dim.clamp(0.0, .92);
    return Stack(fit: StackFit.expand, children: [
      img,
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bg.withOpacity((d * .75).clamp(0.0, 1.0)),
              bg.withOpacity((d * .55).clamp(0.0, 1.0)),
              bg.withOpacity((d * 1.25).clamp(0.0, .96)),
            ],
            stops: [0, .45, 1],
          ),
        ),
      ),
    ]);
  }

  Widget _fallback(BuildContext context, Object error, StackTrace? stack) => ColoredBox(color: C.bg);
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

class _DecorPainter extends CustomPainter {
  _DecorPainter(this.p);
  final AppPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7); // fixed seed: the ornament stays in place
    switch (p.decor) {
      case Decor.sakura:
        _sakura(canvas, size, rnd);
      case Decor.grid:
        _grid(canvas, size);
      case Decor.embers:
        _embers(canvas, size, rnd);
      case Decor.neon:
        _neon(canvas, size);
      case Decor.fog:
        _fog(canvas, size, rnd);
      case Decor.scan:
        _scan(canvas, size);
      case Decor.petals:
        _petals(canvas, size, rnd);
      case Decor.none:
        break;
    }
  }

  void _sakura(Canvas canvas, Size size, math.Random rnd) {
    final count = (size.width * size.height / 26000).clamp(18, 70).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final s = 5 + rnd.nextDouble() * 9;
      final a = rnd.nextDouble() * math.pi;
      final color = (i % 3 == 0 ? p.lilac : p.accent).withOpacity(.07 + rnd.nextDouble() * .10);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(a);
      final petal = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * .9, -s * .2, 0, s)
        ..quadraticBezierTo(-s * .9, -s * .2, 0, -s)
        ..close();
      canvas.drawPath(petal, Paint()..color = color);
      canvas.restore();
    }
  }

  void _grid(Canvas canvas, Size size) {
    final line = Paint()
      ..color = p.accent.withOpacity(.045)
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    // a diagonal light streak across the top
    final streak = Paint()
      ..shader = LinearGradient(colors: [p.accent.withOpacity(0), p.accent.withOpacity(.07), p.accent.withOpacity(0)])
          .createShader(Rect.fromLTWH(0, 0, size.width, 260));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .35, 0)
        ..lineTo(size.width * .55, 0)
        ..lineTo(size.width * .35, 260)
        ..lineTo(size.width * .15, 260)
        ..close(),
      streak,
    );
  }

  void _embers(Canvas canvas, Size size, math.Random rnd) {
    // dark vignette at the edges
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(.45)],
          stops: const [.55, 1],
          radius: .9,
        ).createShader(rect),
    );
    final count = (size.width * size.height / 14000).clamp(30, 120).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      // more embers near the bottom, as if rising from a fire
      final y = size.height * (1 - math.pow(rnd.nextDouble(), 1.8));
      final r = .8 + rnd.nextDouble() * 1.8;
      final c = (i % 4 == 0 ? p.overdue : (i % 3 == 0 ? p.sun : p.deadline)).withOpacity(.18 + rnd.nextDouble() * .35);
      canvas.drawCircle(Offset(x, y), r * 3, Paint()..color = c.withOpacity(c.opacity * .18));
      canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
    }
  }

  void _neon(Canvas canvas, Size size) {
    final scan = Paint()..color = Colors.white.withOpacity(.018);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
    // perspective grid on the floor
    final horizon = size.height * .72;
    final g = Paint()
      ..color = p.lilac.withOpacity(.10)
      ..strokeWidth = 1;
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      final y = horizon + (size.height - horizon) * t * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final cx = size.width / 2;
    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(Offset(cx + i * 30, horizon), Offset(cx + i * size.width / 6, size.height), g);
    }
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..color = p.overdue.withOpacity(.35)
        ..strokeWidth = 1.5,
    );
  }

  void _fog(Canvas canvas, Size size, math.Random rnd) {
    // soft horizontal mist bands, denser near the bottom
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.35 + .65 * rnd.nextDouble());
      final w = size.width * (.6 + rnd.nextDouble() * .8);
      final x = rnd.nextDouble() * size.width - w * .3;
      final h = 90 + rnd.nextDouble() * 160;
      final r = Rect.fromLTWH(x, y - h / 2, w, h);
      canvas.drawOval(
        r,
        Paint()
          ..color = p.muted.withOpacity(.05 + rnd.nextDouble() * .05)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * .45),
      );
    }
  }

  void _scan(Canvas canvas, Size size) {
    final scan = Paint()..color = Colors.black.withOpacity(.10);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scan);
    }
    // thin neon edges
    final rect = Offset.zero & size;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 2),
      Paint()..shader = LinearGradient(colors: [p.overdue, p.lilac, p.workout]).createShader(rect),
    );
  }

  void _petals(Canvas canvas, Size size, math.Random rnd) {
    final count = (size.width * size.height / 60000).clamp(10, 34).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final s = 4 + rnd.nextDouble() * 6;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 2, height: s),
        Paint()..color = p.accent.withOpacity(.25 + rnd.nextDouble() * .35),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DecorPainter old) => old.p.id != p.id;
}
