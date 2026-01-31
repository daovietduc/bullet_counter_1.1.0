import 'package:flutter/material.dart';

/// [ModeSelector] là một Widget nút bấm nhỏ (thường nằm ở góc) hiển thị ảnh đại diện
/// của chế độ hiện tại. Khi nhấn vào sẽ mở ra bảng chọn danh sách các chế độ.
class ModeSelector extends StatelessWidget {
  /// Callback trả về dữ liệu chế độ được chọn: [classId], [modeName], [modeImage]
  final Function(int classId, String modeName, String modeImage) onModeSelected;

  /// Tên chế độ đang được áp dụng để hiển thị trạng thái 'đã chọn'
  final String currentModeName;

  /// Đường dẫn ảnh của chế độ hiện tại
  final String? currentModeImage;

  const ModeSelector({
    super.key,
    required this.onModeSelected,
    required this.currentModeName,
    this.currentModeImage,
  });

  /// Hiển thị bảng chọn chế độ từ dưới lên (Bottom Sheet)
  void _showModeSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép sheet cao hơn nếu nội dung nhiều
      backgroundColor: Colors.transparent, // Để lộ bo góc của Container bên trong
      builder: (context) {
        return _ModeSelectorSheetContent(
          onModeSelected: onModeSelected,
          currentModeName: currentModeName,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showModeSelectionSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          // Sử dụng withValues (API mới của Flutter) để tùy chỉnh độ trong suốt
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildImageWidget(currentModeImage),
        ),
      ),
    );
  }

  /// Widget hiển thị ảnh chế độ, xử lý trường hợp ảnh lỗi hoặc không có ảnh
  Widget _buildImageWidget(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.broken_image, color: Colors.white, size: 24),
      );
    } else {
      return const Icon(Icons.category, color: Colors.white, size: 24);
    }
  }
}

/// [_ModeSelectorSheetContent] nội dung bên trong của bảng chọn chế độ.
/// Được tách ra thành một Private Class để code sạch sẽ và dễ quản lý.
class _ModeSelectorSheetContent extends StatelessWidget {
  final Function(int classId, String modeName, String modeImage) onModeSelected;
  final String currentModeName;

  const _ModeSelectorSheetContent({
    required this.onModeSelected,
    required this.currentModeName,
  });

  @override
  Widget build(BuildContext context) {
    // DANH SÁCH CÁC CHẾ ĐỘ ĐẾM (Hard-coded)
    // Lưu ý: Trong thực tế, danh sách này có thể lấy từ một file cấu hình hoặc API.
    final List<Map<String, dynamic>> modes = [
      {"name": "K51", "image": "assets/images/K51.png", "classID": 0},
      {"name": "K59", "image": "assets/images/K59.png", "classID": 1},
      {"name": "K56", "image": "assets/images/K56.png", "classID": 2},
      {"name": "K53", "image": "assets/images/K53.png", "classID": 3},
      {"name": "12,7mm", "image": "assets/images/12,7.png", "classID": 4},
      {"name": "14,5mm", "image": "assets/images/14,5.png", "classID": 5},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F7), // Màu nền xám nhạt kiểu iOS
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Chỉ chiếm không gian vừa đủ với nội dung
        children: [
          const SizedBox(height: 12),
          // Thanh Handle nhỏ trên cùng để người dùng biết có thể vuốt xuống để đóng
          Container(
            height: 5,
            width: 45,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Select Bullet Type",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          // Hiển thị danh sách chế độ dưới dạng lưới (Grid)
          GridView.builder(
            shrinkWrap: true, // Quan trọng: Cho phép GridView nằm trong Column
            physics: const NeverScrollableScrollPhysics(), // Để Scroll theo Column mẹ
            padding: const EdgeInsets.only(bottom: 30),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,        // 3 cột mỗi hàng
              crossAxisSpacing: 15,     // Khoảng cách ngang giữa các item
              mainAxisSpacing: 15,      // Khoảng cách dọc giữa các item
              childAspectRatio: 0.85,   // Tỷ lệ khung hình của mỗi ô item
            ),
            itemCount: modes.length,
            itemBuilder: (context, index) {
              final mode = modes[index];
              final bool isSelected = currentModeName == mode["name"];

              return InkWell(
                onTap: () {
                  // Gọi callback và đóng bảng chọn
                  onModeSelected(mode["classID"], mode["name"], mode["image"]);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    // Hiển thị viền xanh nếu chế độ này đang được chọn
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hiển thị ảnh minh họa loại đạn
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              mode["image"],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Tên loại đạn
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                        child: Text(
                          mode["name"],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.blueAccent : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}