import 'package:flutter/material.dart';

/// [ProcessedDetection] là lớp chứa dữ liệu đã được tính toán/biến đổi (processed).
/// Nó giúp tách biệt logic tính toán tọa độ và logic vẽ (UI), giúp code sạch hơn.
class ProcessedDetection {
  /// Đường dẫn hình học (Path) của vật thể đã được định hình.
  /// Dùng để vẽ trực tiếp bằng lệnh `canvas.drawPath(path, paint)`.
  final Path path;

  /// Danh sách các đỉnh (tọa độ X, Y) đã được co giãn (scale) theo kích thước màn hình.
  /// Khác với tọa độ gốc từ model AI, tọa độ này có thể dùng để vẽ ngay.
  final List<Offset> scaledVertices;

  /// Điểm trung tâm của vật thể trên màn hình.
  /// Thường dùng để xác định vị trí đặt số thứ tự hoặc nhãn văn bản (label).
  final Offset center;

  /// Độ dài của cạnh nhỏ hơn trong khung hình chữ nhật bao quanh vật thể.
  /// Thường dùng để tính toán kích thước font chữ hoặc icon sao cho tỉ lệ với vật thể.
  final double smallerSide;

  /// Màu sắc được chỉ định cho vật thể này (ví dụ: mỗi loại vật thể một màu).
  final Color color;

  /// Số thứ tự của vật thể trong danh sách phát hiện (ví dụ: vật thể thứ 1, thứ 2...).
  final int orderNumber;

  /// Chuỗi văn bản hiển thị độ tin cậy (ví dụ: "95%").
  /// Đã được định dạng sẵn từ kiểu double (0.95) sang String để chỉ việc hiển thị.
  final String confidenceText;

  /// Constructor để khởi tạo đối tượng với đầy đủ các thông số bắt buộc.
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