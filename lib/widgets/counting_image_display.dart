import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../services/detection_processor.dart';
import '../screens/bounding_box_painter.dart';

/// [ImageDisplay] đảm nhận việc hiển thị ảnh và vẽ các khung nhận diện (Bounding Boxes).
/// Widget này xử lý việc khớp tỷ lệ giữa tọa độ ảnh gốc của AI và kích thước màn hình thực tế.
class ImageDisplay extends StatelessWidget {
  // --- DỮ LIỆU ĐẦU VÀO ---
  final ui.Image? originalImage;           // Đối tượng ảnh đã decode để lấy kích thước gốc
  final String imagePath;                  // Đường dẫn file để hiển thị bằng Image.file
  final List<DetectionResult> detectionResults; // Danh sách kết quả trả về từ model AI
  final bool isFromAlbum;

  // --- CẤU HÌNH HIỂN THỊ (Từ Drawer truyền xuống) ---
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;
  final bool isMultiColor;
  final double fillOpacity;
  final Color boxColor;

  const ImageDisplay({
    super.key,
    required this.originalImage,
    required this.imagePath,
    required this.isFromAlbum,
    required this.detectionResults,
    required this.showBoundingBoxes,
    required this.showConfidence,
    required this.showFillBox,
    required this.showOrderNumber,
    required this.isMultiColor,
    required this.fillOpacity,
    required this.boxColor,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Kiểm tra trạng thái tải ảnh
    if (originalImage == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.amber));
    }

    // 2. Sử dụng LayoutBuilder để lấy kích thước vùng hiển thị khả dụng (Constraints)
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1. Kích thước ảnh gốc từ AI
        double imgW = originalImage!.width.toDouble();
        double imgH = originalImage!.height.toDouble();
        double imgRatio = imgW / imgH;

        // 2. TÍNH TOÁN KÍCH THƯỚC HIỂN THỊ ĐỘNG
        double displayWidth;
        double displayHeight;

        if (isFromAlbum) {
          // NẾU TỪ ALBUM: Khung hiển thị phải khớp chính xác với tỷ lệ ảnh gốc
          displayWidth = constraints.maxWidth;
          displayHeight = constraints.maxWidth / imgRatio;

          // Trường hợp ảnh quá dài, giới hạn theo chiều cao tối đa của màn hình
          if (displayHeight > constraints.maxHeight) {
            displayHeight = constraints.maxHeight;
            displayWidth = displayHeight * imgRatio;
          }
        } else {
          // NẾU TỪ CAMERA: Giữ nguyên khung 3:4 để đồng bộ với lúc chụp
          displayWidth = constraints.maxWidth;
          displayHeight = constraints.maxWidth / (3 / 4);
        }

        return InteractiveViewer(
          clipBehavior: Clip.none,
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                children: [
                  // LỚP 1: Ảnh gốc
                  Positioned.fill(
                    child: Image.file(
                      File(imagePath),
                      // BoxFit.fill là an toàn nhất khi khung SizedBox đã khớp tỷ lệ mục tiêu
                      fit: isFromAlbum ? BoxFit.fill : BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),

                  // LỚP 2: Vẽ khung nhận diện
                  if (detectionResults.isNotEmpty)
                    Positioned.fill(
                      child: _buildPainter(
                          displayWidth, displayHeight, imgW, imgH),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Hàm phụ trợ để chuẩn bị dữ liệu và khởi tạo Painter
  /// [dW], [dH]: Kích thước thực tế đang hiển thị trên màn hình
  /// [oW], [oH]: Kích thước gốc của file ảnh
  Widget _buildPainter(double dW, double dH, double oW, double oH) {
    // Chuyển đổi tọa độ từ hệ quy chiếu "Ảnh gốc" sang hệ quy chiếu "Màn hình"
    // Đây là bước quan trọng để các khung bao khớp chính xác với vật thể sau khi resize ảnh.
    final processedData = DetectionProcessor.process(
      results: detectionResults,
      originalSize: Size(oW, oH),
      screenSize: Size(dW, dH),
      baseBoxColor: boxColor,
      isMultiColor: isMultiColor,
    );

    return CustomPaint(
      painter: BoundingBoxPainter(
        processedResults: processedData,
        showBoundingBoxes: showBoundingBoxes,
        showConfidence: showConfidence,
        showFillBox: showFillBox,
        showOrderNumber: showOrderNumber,
        fillOpacity: fillOpacity,
      ),
    );
  }
}