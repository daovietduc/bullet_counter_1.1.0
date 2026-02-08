import 'package:flutter/material.dart';
import 'menu_mode_selector.dart';

/// [CountingBottomBar] là thanh điều khiển phía dưới của màn hình đếm.
/// Nó chứa các nút chức năng chính: Lưu ảnh, Bắt đầu đếm (AI), và Chọn chế độ.
class CountingBottomBar extends StatelessWidget {
  final bool isCounting;
  final String currentModeName;
  final String? currentModeImage;
  final VoidCallback onCountPressed;
  final VoidCallback onSavePressed;
  final Function(int, String, String?) onModeSelected;

  const CountingBottomBar({
    super.key,
    required this.isCounting,
    required this.currentModeName,
    this.currentModeImage,
    required this.onCountPressed,
    required this.onSavePressed,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Nền đen đồng bộ với giao diện camera/ảnh
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40), // Padding rộng phía dưới cho iPhone (Safe Area)
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- LỚP GIỮA: NÚT BẤM COUNT ---
          // Sử dụng Align để đảm bảo nút COUNT luôn nằm chính giữa tuyệt đối
          Align(
            alignment: Alignment.center,
            child: ElevatedButton(
              // Nếu đang đếm thì onPressed = null (vô hiệu hóa nút)
              onPressed: isCounting ? null : onCountPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                // Màu xám khi nhấn vào (Overlay)
                foregroundColor: Colors.white, // Màu chữ/icon mặc định
                disabledBackgroundColor: Colors.grey.shade400, // Màu khi bị vô hiệu hóa
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ).copyWith(
                // Cách tùy chỉnh màu khi nhấn chuẩn xác nhất
                overlayColor: WidgetStateProperty.resolveWith<Color?>(
                      (Set<WidgetState> states) {
                    if (states.contains(WidgetState.pressed)) return Colors.grey;
                    return null; // Trở về mặc định
                  },
                ),
              ),

              child: Text(
                'COUNT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lexend',
                  shadows: [
                    Shadow(
                      blurRadius: 20.0,
                      color: Colors.black87,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- LỚP TRÊN: CÁC NÚT CHỨC NĂNG HAI BÊN ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nút bên trái: Lưu kết quả
              IconButton(
                icon: const Icon(
                    Icons.download_for_offline_rounded,
                    color: Colors.white,
                    size: 45
                ),
                onPressed: isCounting ? null : onSavePressed,
                tooltip: 'Lưu ảnh vào thư viện',
              ),

              // Nút bên phải: Thành phần chọn chế độ đếm
              // Được tách ra thành một Widget riêng (ModeSelector) để giảm độ phức tạp
              ModeSelector(
                currentModeName: currentModeName,
                currentModeImage: currentModeImage,
                onModeSelected: onModeSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}