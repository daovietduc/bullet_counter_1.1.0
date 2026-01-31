import 'dart:ui';

/// LỚP DỮ LIỆU KẾT QUẢ DỰ ĐOÁN (DETECTION RESULT)
/// Lưu trữ thông tin chi tiết của một vật thể được phát hiện bởi mô hình YOLO-OBB.
class DetectionResult {
  /// 1. DANH SÁCH CÁC ĐỈNH XOAY (ROTATED VERTICES)
  /// Chứa 4 tọa độ [Offset(x, y)] đại diện cho 4 góc của hình chữ nhật xoay.
  /// Đây là thành phần quan trọng nhất để vẽ viền ôm sát vật thể (như thuyền, máy bay).
  /// Thứ tự thường là: Top-Left, Top-Right, Bottom-Right, Bottom-Left.
  final List<Offset> rotatedVertices;

  /// 2. ĐỘ TIN CẬY (CONFIDENCE SCORE)
  /// Giá trị từ 0.0 đến 1.0 thể hiện xác suất mô hình tin rằng đây là vật thể thật.
  /// Thường dùng để hiển thị phần trăm (VD: 0.95 -> 95%).
  final double confidence;

  /// 3. ID PHÂN LỚP (CLASS ID)
  /// Mã số định danh của loại vật thể (VD: 0 cho 'Máy bay', 1 cho 'Tàu thủy').
  /// Dùng để lọc kết quả hoặc gán màu sắc riêng biệt cho từng loại.
  final int classId;

  /// 4. TÊN PHÂN LỚP (CLASS NAME)
  /// Tên hiển thị tương ứng với classId (VD: "Plane", "Ship").
  /// Dữ liệu này được lấy từ file 'labels.txt'.
  final String className;

  /// 5. KHUNG BAO ĐỨNG (BOUNDING BOX - AABB)
  /// Là hình chữ nhật đứng nhỏ nhất bao quanh toàn bộ 4 đỉnh xoay.
  /// Thường dùng để:
  /// - Tính toán nhanh diện tích vùng vật thể.
  /// - Hiển thị nhãn văn bản (Label) ở vị trí cố định (VD: góc trên bên trái).
  /// - Tăng tốc độ thuật toán lọc trùng NMS cơ bản.
  final Rect boundingBox;

  DetectionResult({
    required this.rotatedVertices,
    required this.confidence,
    required this.classId,
    required this.className,
    required this.boundingBox,
  });
}