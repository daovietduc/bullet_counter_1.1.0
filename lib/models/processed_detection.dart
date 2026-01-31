import 'package:flutter/material.dart';

/// Chứa dữ liệu đã được xử lý để sẵn sàng vẽ lên màn hình.
class ProcessedDetection {
  final Path path;
  final List<Offset> scaledVertices;
  final Offset center;
  final double smallerSide;
  final Color color;
  final int orderNumber;
  final String confidenceText;

  ProcessedDetection({
    required this.path,
    required this.scaledVertices,
    required this.center,
    required this.smallerSide,
    required this.color,
    required this.orderNumber,
    required this.confidenceText,
  });
}