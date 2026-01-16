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
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintFutureLine = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGrid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(color: Colors.white54, fontSize: 10);

    // Coordinate
    double w = size.width;
    double h = size.height;
    double paddingBottom = 20.0;
    double paddingLeft = 30.0;

    // Normalizzazione Tempo (X axis)
    DateTime start = points.first.time;
    DateTime end = points.last.time;
    int totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes == 0) totalMinutes = 1;

    // Disegna Griglia Orizzontale (Energia 0, 50, 100)
    for (int i = 0; i <= 100; i += 50) {
      double y = h - paddingBottom - (i / 100 * (h - paddingBottom));
      canvas.drawLine(Offset(paddingLeft, y), Offset(w, y), paintGrid);

      final textSpan = TextSpan(text: '$i%', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // Disegna Linee
    Path pastPath = Path();
    Path futurePath = Path();
    bool firstPast = true;
    bool firstFuture = true;

    // Per disegnare i punti di transizione correttamente
    Offset? lastPastPoint;

    for (var p in points) {
      // Calcola X
      int minsFromStart = p.time.difference(start).inMinutes;
      double x = paddingLeft + (minsFromStart / totalMinutes) * (w - paddingLeft);

      // Calcola Y (Energia)
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
          // Collega al passato se esiste
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

      // Disegna icone acqua
      if (p.isWaterTime) {
        final waterPaint = Paint()..color = Colors.blueAccent;
        canvas.drawCircle(Offset(x, y - 10), 3, waterPaint);
      }

      // Disegna etichette orarie (ogni 4 ore)
      if (p.time.minute == 0 && p.time.hour % 4 == 0) {
        final timeSpan = TextSpan(text: '${p.time.hour}:00', style: textStyle);
        final tp = TextPainter(text: timeSpan, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(x - 10, h - 15));
      }
    }

    canvas.drawPath(pastPath, paintLine);
    // Disegna futuro tratteggiato (simulato con opacità per semplicità in CustomPainter puro)
    canvas.drawPath(futurePath, paintFutureLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}