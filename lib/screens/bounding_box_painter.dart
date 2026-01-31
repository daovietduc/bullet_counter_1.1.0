import 'package:flutter/material.dart';
import '../models/processed_detection.dart';

/// [BoundingBoxPainter] là lớp thực hiện việc vẽ các khung bao và thông tin nhận diện.
/// Nó nhận dữ liệu đã được tính toán tỷ lệ (scaled) từ [DetectionProcessor].
class BoundingBoxPainter extends CustomPainter {
  final List<ProcessedDetection> processedResults; // Danh sách kết quả đã xử lý tọa độ

  // --- CÁC CẤU HÌNH HIỂN THỊ (Từ Drawer truyền vào) ---
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
    // Duyệt qua từng vật thể đã nhận diện để vẽ
    for (var item in processedResults) {

      // 1. TÔ MÀU NỀN (FILL)
      // Tạo một lớp phủ màu nhẹ bên trong khung bao để làm nổi bật vật thể.
      if (showFillBox) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = item.color.withOpacity(fillOpacity);
        canvas.drawPath(item.path, fillPaint);
      }

      // 2. VẼ KHUNG VIỀN (BOUNDING BOXES)
      if (showBoundingBoxes) {
        // TÍNH TOÁN ĐỘ DÀY NÉT VẼ ĐỘNG:
        // Cạnh nhỏ của vật thể càng lớn thì nét vẽ càng dày (giới hạn từ 0.5 đến 3.0).
        final double dynamicStrokeWidth = (item.smallerSide * 0.05).clamp(0.5, 3.0);

        final edgePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dynamicStrokeWidth
          ..color = item.color.withOpacity(0.8);

        canvas.drawPath(item.path, edgePaint);
      }

      // 3. VẼ ĐỘ TIN CẬY (CONFIDENCE LABEL)
      if (showConfidence) {
        _drawConfidenceLabel(canvas, item);
      }

      // 4. VẼ SỐ THỨ TỰ (ORDER NUMBER)
      if (showOrderNumber) {
        _drawOrderNumber(canvas, item);
      }
    }
  }

  /// Hàm phụ trợ vẽ nhãn hiển thị % độ tin cậy của AI.
  void _drawConfidenceLabel(Canvas canvas, ProcessedDetection item) {
    // Cỡ chữ thay đổi theo kích thước vật thể
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

    final labelPos = item.scaledVertices[0]; // Lấy đỉnh đầu tiên làm vị trí đặt nhãn
    final padding = dynamicFontSize * 0.3;

    // VẼ HỘP NỀN CHO NHÃN (Background Label RRect)
    // Tạo một hình chữ nhật bo góc nhỏ phía dưới chữ để dễ đọc hơn trên nền ảnh.
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

    // Vẽ chữ đè lên hộp nền
    textPainter.paint(
      canvas,
      Offset(
        labelPos.dx + padding,
        labelPos.dy - textPainter.height - (padding / 2),
      ),
    );
  }

  /// Hàm phụ trợ vẽ vòng tròn số thứ tự ngay tại tâm vật thể.
  void _drawOrderNumber(Canvas canvas, ProcessedDetection item) {
    // Bán kính vòng tròn thay đổi theo kích thước vật thể
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

    // Vẽ hình tròn nền tại vị trí tâm (center) đã tính từ Processor
    canvas.drawCircle(
      item.center,
      circleRadius,
      Paint()..color = item.color.withAlpha(200),
    );

    // Căn chỉnh chữ số vào chính giữa vòng tròn
    tp.paint(canvas, item.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) => true;
}