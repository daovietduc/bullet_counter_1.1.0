import 'dart:math';
import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../models/processed_detection.dart';

class DetectionProcessor {
  static List<ProcessedDetection> process({
    required List<DetectionResult> results,
    required Size originalSize,
    required Size screenSize,
    required Color baseBoxColor,
    required bool isMultiColor,
  }) {
    if (results.isEmpty || originalSize.width == 0) return [];

    // 1. Tính toán Scale và Offset
    final double scaleX = screenSize.width / originalSize.width;
    final double scaleY = screenSize.height / originalSize.height;
    final double scale = min(scaleX, scaleY);
    final double offsetX = (screenSize.width - originalSize.width * scale) / 2;
    final double offsetY =
        (screenSize.height - originalSize.height * scale) / 2;

    // 2. Thực hiện sắp xếp và lấy thông tin cột
    // Trả về một Record chứa danh sách đã sắp xếp và bản đồ màu sắc
    final sortedData = _performSnakeSortWithColumns(results);
    final List<DetectionResult> sortedResults = sortedData.results;
    final Map<DetectionResult, int> columnMapping = sortedData.columnMapping;

    final List<Color> colorPalette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.cyanAccent,
      Colors.purple,
    ];

    // 3. Chuyển đổi sang ProcessedDetection
    return sortedResults.asMap().entries.map((entry) {
      final int index = entry.key;
      final result = entry.value;

      final scaledPoints = result.rotatedVertices
          .map((v) => Offset(v.dx * scale + offsetX, v.dy * scale + offsetY))
          .toList();

      final path = Path()..moveTo(scaledPoints[0].dx, scaledPoints[0].dy);
      for (var i = 1; i < scaledPoints.length; i++) {
        path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
      }
      path.close();

      // Quyết định màu sắc: Nếu isMultiColor = true, dùng màu theo cột
      final Color finalColor = isMultiColor
          ? colorPalette[columnMapping[result]! % colorPalette.length]
          : baseBoxColor;

      return ProcessedDetection(
        path: path,
        scaledVertices: scaledPoints,
        center: Offset(
          scaledPoints.map((v) => v.dx).reduce((a, b) => a + b) /
              scaledPoints.length,
          scaledPoints.map((v) => v.dy).reduce((a, b) => a + b) /
              scaledPoints.length,
        ),
        smallerSide: _calculateSmallerSide(scaledPoints),
        color: finalColor,
        // Màu đã được tính toán xong ở đây
        orderNumber: index + 1,
        confidenceText: '${(result.confidence * 100).toStringAsFixed(0)}%',
      );
    }).toList();
  }

  // Hàm hỗ trợ tính toán logic Snake Sort và lưu lại chỉ số cột
  static ({
    List<DetectionResult> results,
    Map<DetectionResult, int> columnMapping,
  })
  _performSnakeSortWithColumns(List<DetectionResult> results) {
    final List<DetectionResult> tempResults = List.from(results);
    final Map<DetectionResult, int> columnMapping = {};

    // Sắp xếp theo trục X trung bình
    tempResults.sort((a, b) => _getAvgX(a).compareTo(_getAvgX(b)));

    // Phân nhóm thành các cột
    List<List<DetectionResult>> columns = [];
    for (var result in tempResults) {
      double rx = _getAvgX(result);
      bool addedToCol = false;
      for (var col in columns) {
        double colX =
            col.map((e) => _getAvgX(e)).reduce((a, b) => a + b) / col.length;
        double rWidth =
            (result.rotatedVertices[0] - result.rotatedVertices[3]).distance;

        if ((rx - colX).abs() < rWidth * 1.5) {
          col.add(result);
          addedToCol = true;
          break;
        }
      }
      if (!addedToCol) columns.add([result]);
    }

    // Sắp xếp trong từng cột và tạo Snake Sort
    List<DetectionResult> sortedResults = [];
    for (int i = 0; i < columns.length; i++) {
      for (var res in columns[i])
        columnMapping[res] = i; // Lưu chỉ số cột cho mỗi kết quả

      columns[i].sort((a, b) => _getAvgY(a).compareTo(_getAvgY(b)));
      if (i % 2 != 0) {
        sortedResults.addAll(columns[i].reversed);
      } else {
        sortedResults.addAll(columns[i]);
      }
    }
    return (results: sortedResults, columnMapping: columnMapping);
  }

  static double _getAvgX(DetectionResult r) =>
      r.rotatedVertices.map((v) => v.dx).reduce((a, b) => a + b) /
      r.rotatedVertices.length;

  static double _getAvgY(DetectionResult r) =>
      r.rotatedVertices.map((v) => v.dy).reduce((a, b) => a + b) /
      r.rotatedVertices.length;

  static double _calculateSmallerSide(List<Offset> points) {
    double s1 = (points[1] - points[0]).distance;
    double s2 = (points[2] - points[1]).distance;
    return min(s1, s2);
  }
}
