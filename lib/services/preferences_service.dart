import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SelectedMode] là mô hình dữ liệu đại diện cho loại đối tượng đang được chọn để đếm.
/// Giúp định danh chính xác class mà AI cần nhận diện trong model YOLO.
class SelectedMode {
  final int targetClass; // ID của lớp đối tượng trong file labels.txt (ví dụ: 0, 1, 2...)
  final String name;     // Tên hiển thị của chế độ (ví dụ: "Đạn K51")
  final String image;    // Đường dẫn ảnh minh họa cho chế độ này

  SelectedMode({required this.targetClass, required this.name, required this.image});
}

/// [DisplayPreferences] chứa các thiết lập về thẩm mỹ và cách trình bày kết quả.
/// Model này giúp đóng gói toàn bộ trạng thái cấu hình để truyền đi hoặc lưu trữ dễ dàng.
class DisplayPreferences {
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;
  final bool showMultiColor; // True: Mỗi đối tượng một màu | False: Tất cả dùng một màu cố định
  final Color boxColor;      // Màu được dùng khi showMultiColor = false
  final double opacity;      // Độ trong suốt của phần tô màu (từ 0.0 đến 1.0)

  DisplayPreferences({
    this.showBoundingBoxes = true,
    this.showConfidence = true,
    this.showFillBox = false,
    this.showOrderNumber = false,
    this.showMultiColor = true,
    this.boxColor = Colors.redAccent,
    this.opacity = 0.4, // Cập nhật: Thường dùng scale 0.0-1.0 cho opacity trong Flutter
  });
}

/// [PreferencesService] chịu trách nhiệm đọc/ghi dữ liệu vào bộ nhớ máy (Local Storage).
/// Sử dụng thư viện [SharedPreferences] để duy trì trạng thái ứng dụng sau khi tắt/mở lại.
class PreferencesService {
  // --- ĐỊNH NGHĨA CÁC KHÓA (KEYS) ---
  // Việc sử dụng hằng số (static const) giúp tránh lỗi đánh máy (typo) khi truy xuất dữ liệu.

  // Khóa cho SelectedMode
  static const String _selectedTargetClassKey = 'selectedTargetClass';
  static const String _selectedModeNameKey = 'selectedModeName';
  static const String _selectedModeImageKey = 'selectedModeImage';

  // Khóa cho DisplayPreferences
  static const String _showBoundingBoxesKey = 'showBoundingBoxes';
  static const String _showConfidenceKey = 'showConfidence';
  static const String _showFillBoxKey = 'showFillBox';
  static const String _showOrderNumberKey = 'showOrderNumber';
  static const String _showMultiColorKey = 'showMultiColor';
  static const String _boxColorKey = 'boxColor';
  static const String _opacityKey = 'boxOpacity';

  // --- QUẢN LÝ CHẾ ĐỘ ĐẾM (SelectedMode) ---

  /// Lưu đối tượng [SelectedMode] xuống bộ nhớ.
  /// Được gọi mỗi khi người dùng chọn một loại đạn mới trong BottomSheet.
  Future<void> saveSelectedMode(SelectedMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTargetClassKey, mode.targetClass);
    await prefs.setString(_selectedModeNameKey, mode.name);
    await prefs.setString(_selectedModeImageKey, mode.image);
  }

  /// Tải thông tin chế độ đã lưu.
  /// Nếu là lần đầu mở app (chưa có dữ liệu), hàm sẽ trả về null.
  Future<SelectedMode?> loadSelectedMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_selectedTargetClassKey)) {
      final targetClass = prefs.getInt(_selectedTargetClassKey);
      final name = prefs.getString(_selectedModeNameKey) ?? 'Mode';
      final image = prefs.getString(_selectedModeImageKey) ?? '';

      if (targetClass != null) {
        return SelectedMode(targetClass: targetClass, name: name, image: image);
      }
    }
    return null;
  }

  // --- QUẢN LÝ TÙY CHỌN HIỂN THỊ (DisplayPreferences) ---

  /// Lưu các cấu hình hiển thị (Drawer options).
  /// [prefsData] chứa toàn bộ các trạng thái bật/tắt của giao diện.
  Future<void> saveDisplayPreferences(DisplayPreferences prefsData) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setBool(_showBoundingBoxesKey, prefsData.showBoundingBoxes);
    await instance.setBool(_showConfidenceKey, prefsData.showConfidence);
    await instance.setBool(_showFillBoxKey, prefsData.showFillBox);
    await instance.setBool(_showOrderNumberKey, prefsData.showOrderNumber);
    await instance.setBool(_showMultiColorKey, prefsData.showMultiColor);

    // Lưu màu sắc dưới dạng số nguyên (integer) bằng giá trị .value
    await instance.setInt(_boxColorKey, prefsData.boxColor.value);
    await instance.setDouble(_opacityKey, prefsData.opacity);
  }

  /// Tải các cấu hình hiển thị.
  /// Nếu không có dữ liệu cũ, sẽ sử dụng các giá trị mặc định được định nghĩa trong hàm.
  Future<DisplayPreferences> loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Sử dụng toán tử ?? (null-coalescing) để gán giá trị mặc định nếu null
    final showBoxes = prefs.getBool(_showBoundingBoxesKey) ?? true;
    final showConfidence = prefs.getBool(_showConfidenceKey) ?? true;
    final showFillBox = prefs.getBool(_showFillBoxKey) ?? false;
    final showOrderNumber = prefs.getBool(_showOrderNumberKey) ?? false;
    final showMultiColor = prefs.getBool(_showMultiColorKey) ?? true;

    // Phục hồi màu sắc từ số nguyên đã lưu
    final colorValue = prefs.getInt(_boxColorKey) ?? Colors.redAccent.value;
    final opacity = prefs.getDouble(_opacityKey) ?? 0.4;

    return DisplayPreferences(
      showBoundingBoxes: showBoxes,
      showConfidence: showConfidence,
      showFillBox: showFillBox,
      showOrderNumber: showOrderNumber,
      showMultiColor: showMultiColor,
      boxColor: Color(colorValue),
      opacity: opacity,
    );
  }
}