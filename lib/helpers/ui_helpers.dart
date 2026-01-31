import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class UIHelper {
  /// --- 1. HIỂN THỊ LOADING (LỚP PHỦ MỜ TOÀN MÀN HÌNH) ---
  /// Hiển thị một Dialog không thể tắt bằng cách nhấn ra ngoài, dùng để chặn tương tác khi đang xử lý dữ liệu.
  static void showLoadingIndicator(
    BuildContext context, {
    String message = '',
  }) {
    if (!context.mounted)
      return; // Kiểm tra xem Widget còn tồn tại không trước khi hiển thị

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      // Người dùng không thể tự tắt bằng cách nhấn ra ngoài
      barrierLabel: '',
      barrierColor: Colors.black12,
      // Màu nền phía sau khi hiệu ứng bắt đầu
      transitionDuration: const Duration(milliseconds: 500),
      // Thời gian chạy hiệu ứng (0.5 giây)

      // Xây dựng hiệu ứng chuyển cảnh khi Dialog xuất hiện
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1, // Toàn bộ màn hình loading sẽ mờ dần rồi hiện rõ
          child: child,
        );
      },

      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,
          // Chặn nút "Back" trên Android (không cho tắt loading bằng nút quay lại)
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // Nền Scaffold trong suốt để thấy lớp mờ bên dưới
            body: Stack(
              children: [
                // LỚP 1: LỚP NỀN BLUR (ẢNH HƯỞNG ĐẾN CAMERA/GIAO DIỆN PHÍA SAU)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // Chuyển đổi giá trị animation thô sang đường cong mượt mà (EaseInOut)
                    final double curvedValue = Curves.easeInOut.transform(
                      animation.value,
                    );

                    // Độ mờ của hiệu ứng Glassmorphism (Kính mờ)
                    double sigmaValue = curvedValue * 3.5;

                    // Độ đậm của màu đen nền (Alpha chạy từ 0 đến 51)
                    int alphaValue = (curvedValue * 51).round();

                    return Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: sigmaValue,
                          sigmaY: sigmaValue,
                        ),
                        child: Container(
                          color: Colors.black.withAlpha(
                            alphaValue,
                          ), // Phủ một lớp màu tối nhẹ
                        ),
                      ),
                    );
                  },
                ),

                // LỚP 2: NỘI DUNG CHÍNH (ICON XOAY & CHỮ)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sử dụng thư viện SpinKit để tạo icon loading dạng khối vuông nảy
                        SpinKitCubeGrid(color: Colors.white, size: 50.0),
                        const SizedBox(height: 20),
                        // Khoảng cách giữa icon và chữ
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Lexend',
                            letterSpacing: 10.0,
                            // Chữ thưa ra tạo cảm giác sang trọng/hiện đại
                            decoration: TextDecoration.none,
                            // Xóa gạch chân mặc định của Dialog
                            shadows: [
                              Shadow(
                                blurRadius: 15.0,
                                color: Colors.black,
                                offset: Offset(
                                  0,
                                  0,
                                ), // Bóng tỏa đều 4 hướng giúp chữ dễ đọc trên nền mờ
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// --- 2. ẨN LOADING ---
  /// Đóng hộp thoại loading đang hiển thị bằng Navigator pop.
  static void hideLoadingIndicator(BuildContext context) {
    if (context.mounted) {
      // rootNavigator: true đảm bảo đóng đúng cái Dialog vừa mở phía trên
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// --- 3, 4, 5. CÁC THÔNG BÁO NHANH (SNACKBAR) ---
  /// Hiển thị các thông báo màu sắc khác nhau tùy theo trạng thái.

  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green.shade700, Icons.check_circle);
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      Colors.red.shade800,
      Icons.error_outline,
      duration: 3,
    );
  }

  static void showMaintenanceSnackBar(BuildContext context) {
    _showSnackBar(
      context,
      'Tính năng đang phát triển.',
      Colors.orange.shade800,
      Icons.engineering,
    );
  }

  /// --- HÀM DÙNG CHUNG ĐỂ VẼ SNACKBAR ---
  /// Giúp code ngắn gọn, tránh lặp lại logic hiển thị SnackBar.
  static void _showSnackBar(
    BuildContext context,
    String message,
    Color bg,
    IconData icon, {
    int duration = 2,
  }) {
    if (!context.mounted) return;

    // Ẩn SnackBar cũ ngay lập tức nếu nó đang hiện để hiện cái mới lên (tránh xếp hàng chờ)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        // SnackBar nổi lên trên (không dính đáy màn hình)
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        // Bo góc
        duration: Duration(seconds: duration),
      ),
    );
  }
}
