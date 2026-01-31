import 'package:flutter/material.dart';
import '../models/processed_detection.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<ProcessedDetection> processedResults;
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;
  final double fillOpacity;

  BoundingBoxPainter({
    required this.processedResults,
    this.showBoundingBoxes = true,
    this.showConfidence = true,
    this.showFillBox = false,
    this.showOrderNumber = false,
    this.fillOpacity = 0.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var item in processedResults) {
      // 1. Tô màu nền (Fill)
      if (showFillBox) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = item.color.withOpacity(fillOpacity);
        canvas.drawPath(item.path, fillPaint);
      }

      // 2. Vẽ khung viền (Bounding Boxes)
      if (showBoundingBoxes) {
        final double dynamicStrokeWidth = (item.smallerSide * 0.05).clamp(0.5, 3.0,);
        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dynamicStrokeWidth
          ..color = item.color.withOpacity(0.8);

        canvas.drawPath(item.path, edgePaint);
        // Bạn có thể thêm lại logic vẽ 4 góc trắng ở đây nếu muốn giao diện lung linh hơn
      }

      // 3. Vẽ Độ tin cậy (CONFIDENCE)
      if (showConfidence) {
        _drawConfidenceLabel(canvas, item);
      }

      // 4. Vẽ Số thứ tự (Order Number)
      if (showOrderNumber) {
        _drawOrderNumber(canvas, item);
      }
    }
  }

  void _drawConfidenceLabel(Canvas canvas, ProcessedDetection item) {
    final double dynamicFontSize = (item.smallerSide * 0.15).clamp(7.0, 12.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: item.confidenceText,
        style: TextStyle(
          color: Colors.white,
          fontSize: dynamicFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelPos = item.scaledVertices[0]; // Vẽ tại đỉnh đầu tiên của hộp
    final padding = dynamicFontSize * 0.3;

    // Vẽ hộp nền cho chữ (Background label)
    final RRect labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelPos.dx,
        labelPos.dy - textPainter.height - padding,
        textPainter.width + (padding * 2),
        textPainter.height + padding,
      ),
      Radius.circular(padding),
    );

    canvas.drawRRect(labelRect, Paint()..color = item.color.withAlpha(230));
    textPainter.paint(
      canvas,
      Offset(
        labelPos.dx + padding,
        labelPos.dy - textPainter.height - (padding / 2),
      ),
    );
  }

  void _drawOrderNumber(Canvas canvas, ProcessedDetection item) {
    final double circleRadius = (item.smallerSide * 0.3).clamp(5.0, 15.0);
    final tp = TextPainter(
      text: TextSpan(
        text: '${item.orderNumber}',
        style: TextStyle(
          color: Colors.white,
          fontSize: circleRadius * 1.1,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.drawCircle(
      item.center,
      circleRadius,
      Paint()..color = item.color.withAlpha(200),
    );
    tp.paint(canvas, item.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) => true;
}
