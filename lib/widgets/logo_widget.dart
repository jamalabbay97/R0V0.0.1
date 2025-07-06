import 'package:flutter/material.dart';
import 'dart:math';

class OcpLogo extends StatelessWidget {
  final double size;
  const OcpLogo({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _OcpLogoPainter(),
    );
  }
}

class _OcpLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;

    // Draw bar chart
    final barWidth = size.width * 0.15;
    final barSpacing = size.width * 0.08;
    final baseY = size.height * 0.75;
    final bars = [
      size.height * 0.35,
      size.height * 0.65,
      size.height * 0.5,
      size.height * 0.8,
    ];
    for (int i = 0; i < bars.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            barSpacing + i * (barWidth + barSpacing),
            baseY - bars[i],
            barWidth,
            bars[i],
          ),
          Radius.circular(barWidth * 0.2),
        ),
        paint,
      );
    }

    // Draw arrow
    final arrowPaint = Paint()
      ..color = Colors.green[800]!
      ..strokeWidth = size.width * 0.06
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arrowPath = Path();
    arrowPath.moveTo(barSpacing + barWidth / 2, baseY - bars[0]);
    arrowPath.lineTo(barSpacing + barWidth * 1.5 + barSpacing, baseY - bars[1]);
    arrowPath.lineTo(barSpacing + barWidth * 2.5 + barSpacing * 2, baseY - bars[2]);
    arrowPath.lineTo(barSpacing + barWidth * 3.5 + barSpacing * 3, baseY - bars[3] - size.height * 0.08);
    // Arrow head
    arrowPath.moveTo(barSpacing + barWidth * 3.5 + barSpacing * 3, baseY - bars[3] - size.height * 0.08);
    arrowPath.relativeLineTo(size.width * 0.05, size.height * 0.08);
    arrowPath.moveTo(barSpacing + barWidth * 3.5 + barSpacing * 3, baseY - bars[3] - size.height * 0.08);
    arrowPath.relativeLineTo(-size.width * 0.08, size.height * 0.03);
    canvas.drawPath(arrowPath, arrowPaint);

    // Draw circle for emblem
    final circleCenter = Offset(size.width * 0.7, size.height * 0.7);
    final circleRadius = size.width * 0.23;
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);
    final circleBorder = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;
    canvas.drawCircle(circleCenter, circleRadius, circleBorder);

    // Draw star (simple 5-pointed)
    final starPaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;
    final starPath = Path();
    const n = 5;
    final rOuter = circleRadius * 0.7;
    final rInner = rOuter * 0.4;
    for (int i = 0; i < n * 2; i++) {
      final angle = (i * pi / n) - pi / 2;
      final r = i.isEven ? rOuter : rInner;
      final x = circleCenter.dx + r * cos(angle);
      final y = circleCenter.dy + r * sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);

    // Draw laurel (simplified as arcs)
    final laurelPaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.015;
    canvas.drawArc(
      Rect.fromCircle(center: circleCenter, radius: circleRadius * 0.95),
      3.7,
      1.7,
      false,
      laurelPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: circleCenter, radius: circleRadius * 0.95),
      -0.55,
      1.7,
      false,
      laurelPaint,
    );

    // Draw OCP text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'OCP',
        style: TextStyle(
          color: Colors.green[800],
          fontWeight: FontWeight.bold,
          fontSize: size.width * 0.16,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(circleCenter.dx - textPainter.width / 2, circleCenter.dy + circleRadius * 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 