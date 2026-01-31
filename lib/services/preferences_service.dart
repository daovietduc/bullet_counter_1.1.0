import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model: Lưu trữ thông tin về chế độ đếm đã chọn.
class SelectedMode {
  final int targetClass;
  final String name;
  final String image;

  SelectedMode({required this.targetClass, required this.name, required this.image});
}

/// Model: Lưu trữ các tùy chọn hiển thị trên màn hình kết quả.
class DisplayPreferences {
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;
  final bool showMultiColor; // True: vẽ các box với nhiều màu. False: dùng một màu `boxColor`.
  final Color boxColor;      // Màu sắc của box khi `showMultiColor` là false.
  final double opacity;      // Độ trong suốt của box (từ 0.0 đến 1.0).

  DisplayPreferences({
    this.showBoundingBoxes = true,
    this.showConfidence = true,
    this.showFillBox = false,
    this.showOrderNumber = false,
    this.showMultiColor = true,
    this.boxColor = Colors.redAccent,
    this.opacity = 64,
  });
}

/// Service: Quản lý việc lưu và tải các tùy chọn của người dùng.
/// Sử dụng SharedPreferences để lưu trữ dữ liệu cục bộ.
class PreferencesService {
  // Khóa (key) cho SelectedMode
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

  // --- Quản lý Chế độ đếm (SelectedMode) ---

  /// Lưu đối tượng `SelectedMode` vào SharedPreferences.
  Future<void> saveSelectedMode(SelectedMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTargetClassKey, mode.targetClass);
    await prefs.setString(_selectedModeNameKey, mode.name);
    await prefs.setString(_selectedModeImageKey, mode.image);
  }

  /// Tải `SelectedMode` từ SharedPreferences.
  /// Trả về `null` nếu không tìm thấy dữ liệu.
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

  // --- Quản lý Tùy chọn hiển thị (DisplayPreferences) ---

  /// Lưu đối tượng `DisplayPreferences` vào SharedPreferences.
  Future<void> saveDisplayPreferences(DisplayPreferences prefsData) async {
    final instance = await SharedPreferences.getInstance();
    await instance.setBool(_showBoundingBoxesKey, prefsData.showBoundingBoxes);
    await instance.setBool(_showConfidenceKey, prefsData.showConfidence);
    await instance.setBool(_showFillBoxKey, prefsData.showFillBox);
    await instance.setBool(_showOrderNumberKey, prefsData.showOrderNumber);
    await instance.setBool(_showMultiColorKey, prefsData.showMultiColor);
    await instance.setInt(_boxColorKey, prefsData.boxColor.value);
    await instance.setDouble(_opacityKey, prefsData.opacity);
  }

  /// Tải `DisplayPreferences` từ SharedPreferences.
  /// Sử dụng giá trị mặc định nếu không tìm thấy dữ liệu đã lưu.
  Future<DisplayPreferences> loadDisplayPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final showBoxes = prefs.getBool(_showBoundingBoxesKey) ?? true;
    final showConfidence = prefs.getBool(_showConfidenceKey) ?? true;
    final showFillBox = prefs.getBool(_showFillBoxKey) ?? false;
    final showOrderNumber = prefs.getBool(_showOrderNumberKey) ?? false;
    final showMultiColor = prefs.getBool(_showMultiColorKey) ?? true;

    final colorValue = prefs.getInt(_boxColorKey) ?? Colors.redAccent.value;
    final opacity = prefs.getDouble(_opacityKey) ?? 1.0;

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
