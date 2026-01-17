import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/models.dart';

class EnergyChartPainter extends CustomPainter {
  final List<EnergyPoint> points;
  final DateTime now;
  final Color accentColor;

  EnergyChartPainter({required this.points, required this.now, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double w = size.width;
    final double h = size.height;
    final double paddingBottom = 30.0;
    final double paddingLeft = 0.0; // Full width drawing

    // 1. CONFIGURAZIONE PAINT

    // Linea principale (Passato)
    final paintLinePast = Paint()
      ..color = accentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Linea futura (Tratteggiata/Opaca)
    final paintLineFuture = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Riempimento Sfumato (Gradient Fill)
    final paintFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, h),
        [
          accentColor.withOpacity(0.4),
          accentColor.withOpacity(0.0),
        ],
      );

    // Griglia
    final paintGrid = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500);

    // 2. DISEGNO GRIGLIA & LABELS
    for (int i = 0; i <= 100; i += 25) {
      double y = h - paddingBottom - (i / 100 * (h - paddingBottom));

      // Linea orizzontale
      canvas.drawLine(Offset(0, y), Offset(w, y), paintGrid);

      // Label percentuale (solo 0, 50, 100)
      if (i % 50 == 0) {
        final textSpan = TextSpan(text: '$i%', style: textStyle);
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, Offset(5, y - 12));
      }
    }

    // 3. COSTRUZIONE PATH
    DateTime start = points.first.time;
    DateTime end = points.last.time;
    int totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes == 0) totalMinutes = 1;

    Path fullPath = Path(); // Per il riempimento
    Path pastPath = Path(); // Per la linea solida
    Path futurePath = Path(); // Per la linea tratteggiata

    bool firstPoint = true;
    bool firstFuture = true;
    Offset? lastPastOffset;

    for (var p in points) {
      int minsFromStart = p.time.difference(start).inMinutes;
      double x = paddingLeft + (minsFromStart / totalMinutes) * (w - paddingLeft);
      double y = h - paddingBottom - (p.energyLevel / 100 * (h - paddingBottom));

      Offset pointOffset = Offset(x, y);

      if (firstPoint) {
        fullPath.moveTo(x, y);
        firstPoint = false;
      } else {
        fullPath.lineTo(x, y);
      }

      if (p.isPast) {
        if (pastPath.getBounds().isEmpty) {
          pastPath.moveTo(x, y);
        } else {
          pastPath.lineTo(x, y);
        }
        lastPastOffset = pointOffset;
      } else {
        if (firstFuture) {
          if (lastPastOffset != null) {
            futurePath.moveTo(lastPastOffset.dx, lastPastOffset.dy);
            futurePath.lineTo(x, y);
          } else {
            futurePath.moveTo(x, y);
          }
          firstFuture = false;
        } else {
          futurePath.lineTo(x, y);
        }
      }

      // Marker Acqua
      if (p.isWaterTime) {
        // Glow effect
        canvas.drawCircle(pointOffset, 6, Paint()..color = Colors.blueAccent.withOpacity(0.3)..maskFilter = MaskFilter.blur(BlurStyle.normal, 3));
        // Dot
        canvas.drawCircle(pointOffset, 3, Paint()..color = Colors.cyanAccent);
      }

      // Orari (ogni 4 ore)
      if (p.time.minute == 0 && p.time.hour % 4 == 0) {
        final timeSpan = TextSpan(text: '${p.time.hour}:00', style: textStyle);
        final tp = TextPainter(text: timeSpan, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(x - 12, h - 20));
      }
    }

    // 4. DISEGNO FILL (CHIUSURA PATH)
    // Chiudiamo il path in basso per creare l'area da colorare
    Path fillPath = Path.from(fullPath);
    fillPath.lineTo(w, h - paddingBottom);
    fillPath.lineTo(0, h - paddingBottom);
    fillPath.close();
    canvas.drawPath(fillPath, paintFill);

    // 5. DISEGNO LINEE
    canvas.drawPath(pastPath, paintLinePast);

    // Disegno futuro (tratteggiato simulato disegnando pallini o linea continua semitrasparente)
    // Qui usiamo linea continua semitrasparente per performance e pulizia
    canvas.drawPath(futurePath, paintLineFuture);

    // Indicatore "ADESSO"
    if (lastPastOffset != null) {
      canvas.drawCircle(lastPastOffset, 4, Paint()..color = Colors.white);
      canvas.drawCircle(lastPastOffset, 10, Paint()..color = Colors.white.withOpacity(0.1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}