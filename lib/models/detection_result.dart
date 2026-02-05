import 'dart:ui';

/// [DetectionResult] là Model chứa dữ liệu thô sau khi được mô hình AI xử lý.
/// Lớp này đại diện cho một vật thể đơn lẻ được tìm thấy trong ảnh đầu vào.
class DetectionResult {

  /// 1. DANH SÁCH CÁC ĐỈNH XOAY (ROTATED VERTICES)
  /// Chứa chính xác 4 tọa độ [Offset(x, y)] của hình chữ nhật đã xoay.
  /// Khác với hình chữ nhật đứng, OBB cho phép các cạnh nghiêng theo hướng của vật thể.
  ///
  /// Ý nghĩa: Giúp vẽ khung bao ôm khít vật thể nằm chéo, tránh bao phủ nhầm không gian trống.
  /// Thứ tự lưu trữ: Thường theo chiều kim đồng hồ bắt đầu từ đỉnh phía trên bên trái.
  final List<Offset> rotatedVertices;

  /// 2. ĐỘ TIN CẬY (CONFIDENCE SCORE)
  /// Thể hiện mức độ "chắc chắn" của AI (giá trị từ 0.0 đến 1.0).
  ///
  /// Ứng dụng: Dùng để lọc bỏ các kết quả "nhiễu" (ví dụ: chỉ hiển thị nếu confidence > 0.5).
  final double confidence;

  /// 3. ID PHÂN LỚP (CLASS ID)
  /// Mã số đại diện cho loại vật thể trong tập dữ liệu huấn luyện.
  ///
  /// Ví dụ: 0 tương ứng với K51, 1 tương ứng với K59...
  final int classId;

  /// 4. TÊN PHÂN LỚP (CLASS NAME)
  /// Chuỗi ký tự mô tả vật thể để người dùng có thể đọc được.
  ///
  /// Dữ liệu này giúp hiển thị nhãn trên giao diện thay vì chỉ hiển thị các con số ID khô khan.
  final String className;

  /// 5. KHUNG BAO CHUẨN (AXIS-ALIGNED BOUNDING BOX - AABB)
  /// Là khung hình chữ nhật không xoay, bao quát toàn bộ vùng chứa OBB.
  ///
  /// Tại sao cần: Mặc dù ta dùng OBB để vẽ, nhưng AABB rất hữu ích để:
  /// - Kiểm tra nhanh xem điểm chạm của người dùng (Touch Event) có nằm gần vật thể không.
  /// - Tính toán vị trí đặt các Widget bổ trợ mà không cần tính toán lượng giác phức tạp.
  final Rect boundingBox;

  DetectionResult({
    required this.rotatedVertices,
    required this.confidence,
    required this.classId,
    required this.className,
    required this.boundingBox,
  });
}