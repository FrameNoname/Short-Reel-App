import 'package:flutter/material.dart';

/// Solid speech bubble with three dots cut out, drawn on a 24x24 grid.
class CommentIcon extends StatelessWidget {
  const CommentIcon({super.key, required this.color, this.size = 34});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(_commentPath, color),
  );
}

/// Bold forward arrow with a curled tail, drawn on a 24x24 grid.
class ShareIcon extends StatelessWidget {
  const ShareIcon({super.key, required this.color, this.size = 34});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(_sharePath, color),
  );
}

Path _commentPath() {
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(8.5, 2.6)
    ..lineTo(15.5, 2.6)
    ..arcToPoint(const Offset(21.4, 8.5), radius: const Radius.circular(5.9))
    ..lineTo(21.4, 12)
    ..arcToPoint(const Offset(15.5, 17.9), radius: const Radius.circular(5.9))
    ..lineTo(12.2, 17.9)
    ..lineTo(8, 21.1)
    ..quadraticBezierTo(6.4, 22.2, 6.4, 20.3)
    ..lineTo(6.4, 17.5)
    ..arcToPoint(const Offset(2.6, 12), radius: const Radius.circular(5.9))
    ..lineTo(2.6, 8.5)
    ..arcToPoint(const Offset(8.5, 2.6), radius: const Radius.circular(5.9))
    ..close();
  for (final x in const [8.0, 12.0, 16.0]) {
    path.addOval(Rect.fromCircle(center: Offset(x, 10.25), radius: 1.35));
  }
  return path;
}

Path _sharePath() {
  return Path()
    ..moveTo(13.3, 3.6)
    ..cubicTo(13.3, 2.8, 14.1, 2.4, 14.7, 2.9)
    ..lineTo(22.4, 10.4)
    ..cubicTo(23, 11, 23, 11.9, 22.4, 12.5)
    ..lineTo(14.7, 20)
    ..cubicTo(14.1, 20.5, 13.3, 20.1, 13.3, 19.3)
    ..lineTo(13.3, 15.6)
    ..cubicTo(8.3, 15.6, 4.9, 17.4, 2.9, 21)
    ..cubicTo(2.5, 21.6, 1.7, 21.4, 1.8, 20.7)
    ..cubicTo(2.6, 13.9, 6.6, 9.5, 13.3, 8.8)
    ..close();
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.buildPath, this.color);

  final Path Function() buildPath;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = buildPath().transform(
      Matrix4.diagonal3Values(scale, scale, 1).storage,
    );
    canvas.drawPath(
      path.shift(const Offset(0, 1.5)),
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
}
