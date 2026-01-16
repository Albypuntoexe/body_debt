import 'package:flutter/material.dart';
import '../models/models.dart';

class EnergyChartPainter extends CustomPainter {
  final List<EnergyPoint> points;
  final DateTime now;
  final Color accentColor;

  EnergyChartPainter({required this.points, required this.now, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintLine = Paint()
      ..color = accentColor
      ..strokeWidth = 4.0 // Più spessa
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFutureLine = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGrid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.0;

    // FONT PIÙ GRANDI
    final textStyle = TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold);

    double w = size.width;
    double h = size.height;
    double paddingBottom = 30.0;
    double paddingLeft = 40.0;

    DateTime start = points.first.time;
    DateTime end = points.last.time;
    int totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes == 0) totalMinutes = 1;

    // Griglia Orizzontale
    for (int i = 0; i <= 100; i += 50) {
      double y = h - paddingBottom - (i / 100 * (h - paddingBottom));
      canvas.drawLine(Offset(paddingLeft, y), Offset(w, y), paintGrid);

      final textSpan = TextSpan(text: '$i%', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - 8)); // Offset aggiustato per font più grande
    }

    Path pastPath = Path();
    Path futurePath = Path();
    bool firstPast = true;
    bool firstFuture = true;
    Offset? lastPastPoint;

    for (var p in points) {
      int minsFromStart = p.time.difference(start).inMinutes;
      double x = paddingLeft + (minsFromStart / totalMinutes) * (w - paddingLeft);
      double y = h - paddingBottom - (p.energyLevel / 100 * (h - paddingBottom));
      Offset pointOffset = Offset(x, y);

      if (p.isPast) {
        if (firstPast) {
          pastPath.moveTo(x, y);
          firstPast = false;
        } else {
          pastPath.lineTo(x, y);
        }
        lastPastPoint = pointOffset;
      } else {
        if (firstFuture) {
          if (lastPastPoint != null) {
            futurePath.moveTo(lastPastPoint.dx, lastPastPoint.dy);
            futurePath.lineTo(x, y);
          } else {
            futurePath.moveTo(x, y);
          }
          firstFuture = false;
        } else {
          futurePath.lineTo(x, y);
        }
      }

      // Marker Acqua più visibili
      if (p.isWaterTime) {
        final waterPaint = Paint()..color = Colors.blueAccent;
        canvas.drawCircle(Offset(x, y - 12), 5, waterPaint); // Cerchio più grande
      }

      // Orari (ogni 4 ore)
      if (p.time.minute == 0 && p.time.hour % 4 == 0) {
        final timeSpan = TextSpan(text: '${p.time.hour}:00', style: textStyle.copyWith(fontSize: 12));
        final tp = TextPainter(text: timeSpan, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(x - 15, h - 20));
      }
    }

    canvas.drawPath(pastPath, paintLine);
    canvas.drawPath(futurePath, paintFutureLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}