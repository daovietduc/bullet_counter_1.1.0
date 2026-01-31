import 'dart:math';
import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../models/processed_detection.dart';

/// [DetectionProcessor] là lớp tiện ích xử lý hậu kỳ cho các kết quả nhận diện.
/// Nó chuẩn bị dữ liệu thô từ AI để sẵn sàng cho việc vẽ lên giao diện người dùng.
class DetectionProcessor {

  /// Hàm chính để xử lý danh sách kết quả [results].
  /// [originalSize]: Kích thước thực tế của ảnh đầu vào.
  /// [screenSize]: Kích thước vùng hiển thị trên màn hình.
  static List<ProcessedDetection> process({
    required List<DetectionResult> results,
    required Size originalSize,
    required Size screenSize,
    required Color baseBoxColor,
    required bool isMultiColor,
  }) {
    // Tránh xử lý nếu không có dữ liệu để tiết kiệm tài nguyên
    if (results.isEmpty || originalSize.width == 0) return [];

    // --- BƯỚC 1: TÍNH TOÁN TỶ LỆ VÀ CĂN CHỈNH (SCALING & OFFSET) ---
    // Tìm tỷ lệ co dãn phù hợp nhất để ảnh nằm gọn trong màn hình mà không bị méo.
    final double scaleX = screenSize.width / originalSize.width;
    final double scaleY = screenSize.height / originalSize.height;
    final double scale = min(scaleX, scaleY);

    // Tính toán khoảng bù (offset) để căn giữa hình ảnh khi hiển thị.
    final double offsetX = (screenSize.width - originalSize.width * scale) / 2;
    final double offsetY = (screenSize.height - originalSize.height * scale) / 2;

    // --- BƯỚC 2: SẮP XẾP THỨ TỰ ĐẾM (SNAKE SORT) ---
    // Thay vì hiển thị thứ tự ngẫu nhiên, ta sắp xếp theo cột và zigzag.
    final sortedData = _performSnakeSortWithColumns(results);
    final List<DetectionResult> sortedResults = sortedData.results;
    final Map<DetectionResult, int> columnMapping = sortedData.columnMapping;

    // Bảng màu sắc để phân biệt các cột hoặc đối tượng
    final List<Color> colorPalette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.cyanAccent,
      Colors.purple,
    ];

    // --- BƯỚC 3: CHUYỂN ĐỔI SANG DỮ LIỆU HIỂN THỊ (PROCESSED DATA) ---
    return sortedResults.asMap().entries.map((entry) {
      final int index = entry.key;
      final result = entry.value;

      // Áp dụng Scale và Offset cho từng đỉnh của khung bao (OBB - Oriented Bounding Box)
      final scaledPoints = result.rotatedVertices
          .map((v) => Offset(v.dx * scale + offsetX, v.dy * scale + offsetY))
          .toList();

      // Tạo một Path (đường vẽ kín) từ các đỉnh đã được tính toán lại tọa độ
      final path = Path()..moveTo(scaledPoints[0].dx, scaledPoints[0].dy);
      for (var i = 1; i < scaledPoints.length; i++) {
        path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
      }
      path.close();

      // Quyết định màu sắc:
      // Nếu đa màu (multiColor): Mỗi cột sẽ có một màu riêng biệt từ bảng màu.
      // Nếu đơn màu: Sử dụng màu mặc định người dùng chọn.
      final Color finalColor = isMultiColor
          ? colorPalette[columnMapping[result]! % colorPalette.length]
          : baseBoxColor;

      return ProcessedDetection(
        path: path,
        scaledVertices: scaledPoints,
        // Tính toán tâm của khung bao để đặt số thứ tự hoặc nhãn Text
        center: Offset(
          scaledPoints.map((v) => v.dx).reduce((a, b) => a + b) / scaledPoints.length,
          scaledPoints.map((v) => v.dy).reduce((a, b) => a + b) / scaledPoints.length,
        ),
        smallerSide: _calculateSmallerSide(scaledPoints),
        color: finalColor,
        orderNumber: index + 1, // Thứ tự bắt đầu từ 1
        confidenceText: '${(result.confidence * 100).toStringAsFixed(0)}%',
      );
    }).toList();
  }

  /// Thuật toán sắp xếp theo hình con rắn (Snake Sort).
  /// Logic: Chia các đối tượng vào từng cột dọc, cột lẻ sắp xếp từ trên xuống,
  /// cột chẵn sắp xếp từ dưới lên (hoặc ngược lại) để tạo đường đi liên tục.
  static ({
  List<DetectionResult> results,
  Map<DetectionResult, int> columnMapping,
  })
  _performSnakeSortWithColumns(List<DetectionResult> results) {
    final List<DetectionResult> tempResults = List.from(results);
    final Map<DetectionResult, int> columnMapping = {};

    // 1. Sắp xếp sơ bộ toàn bộ danh sách theo trục X để xác định thứ tự từ trái sang phải
    tempResults.sort((a, b) => _getAvgX(a).compareTo(_getAvgX(b)));

    // 2. Phân nhóm các đối tượng vào các cột dọc (Columns)
    List<List<DetectionResult>> columns = [];
    for (var result in tempResults) {
      double rx = _getAvgX(result);
      bool addedToCol = false;
      for (var col in columns) {
        // Tính X trung bình của cột hiện tại
        double colX = col.map((e) => _getAvgX(e)).reduce((a, b) => a + b) / col.length;
        // Khoảng cách an toàn để coi là cùng một cột (dựa trên chiều rộng vật thể)
        double rWidth = (result.rotatedVertices[0] - result.rotatedVertices[3]).distance;

        if ((rx - colX).abs() < rWidth * 1.5) {
          col.add(result);
          addedToCol = true;
          break;
        }
      }
      if (!addedToCol) columns.add([result]);
    }

    // 3. Thực hiện Snake Sort: Đảo chiều sắp xếp Y ở các cột xen kẽ
    List<DetectionResult> sortedResults = [];
    for (int i = 0; i < columns.length; i++) {
      // Lưu lại thông tin cột để sau này đổ màu theo cột
      for (var res in columns[i]) columnMapping[res] = i;

      // Sắp xếp mặc định theo chiều Y (từ trên xuống)
      columns[i].sort((a, b) => _getAvgY(a).compareTo(_getAvgY(b)));

      // Nếu là cột thứ 2, 4, 6... (chỉ số lẻ), đảo ngược danh sách để tạo hiệu ứng zigzag
      if (i % 2 != 0) {
        sortedResults.addAll(columns[i].reversed);
      } else {
        sortedResults.addAll(columns[i]);
      }
    }
    return (results: sortedResults, columnMapping: columnMapping);
  }

  // --- CÁC HÀM TRỢ GIÚP TÍNH TOÁN HÌNH HỌC ---

  /// Lấy vị trí X trung bình của một khung bao
  static double _getAvgX(DetectionResult r) =>
      r.rotatedVertices.map((v) => v.dx).reduce((a, b) => a + b) / r.rotatedVertices.length;

  /// Lấy vị trí Y trung bình của một khung bao
  static double _getAvgY(DetectionResult r) =>
      r.rotatedVertices.map((v) => v.dy).reduce((a, b) => a + b) / r.rotatedVertices.length;

  /// Tính toán cạnh nhỏ hơn của khung bao (dùng để điều chỉnh kích thước font chữ nhãn)
  static double _calculateSmallerSide(List<Offset> points) {
    double s1 = (points[1] - points[0]).distance;
    double s2 = (points[2] - points[1]).distance;
    return min(s1, s2);
  }
}