import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class UIHelper {
  /// 1. HIỂN THỊ LOADING (FULL SCREEN BLUR ANIMATION)
  /// Hiển thị một hộp thoại loading với hiệu ứng mờ dần tăng dần theo thời gian.
  static void showLoadingIndicator(BuildContext context, {String message = ''}) {
    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black12,
      // Tăng thời gian lên để thấy rõ hiệu ứng mờ dần
      transitionDuration: const Duration(milliseconds: 500),

      transitionBuilder: (context, anim1, anim2, child) {
        // Làm mờ dần toàn bộ nội dung (bao gồm cả chữ và icon)
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },

      pageBuilder: (context, animation, secondaryAnimation) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // LỚP 1: HIỆU ỨNG LÀM MỜ TĂNG DẦN (ANIMATED BLUR)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // 1. Tính toán giá trị trung gian mượt mà với Curves
                    final double curvedValue = Curves.easeInOut.transform(animation.value);

                    // 2. Tính toán Sigma (Độ mờ)
                    double sigmaValue = curvedValue * 3.5;

                    // 3. Tính toán Alpha (Độ trong suốt của màu nền)
                    // 0.2 opacity tương đương với Alpha khoảng 51 (0.2 * 255)
                    int alphaValue = (curvedValue * 51).round();

                    return Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: sigmaValue,
                          sigmaY: sigmaValue,
                        ),
                        child: Container(
                          color: Colors.black.withAlpha(alphaValue),
                        ),
                      ),
                    );
                  },
                ),

                // LỚP 2: NỘI DUNG VĂN BẢN
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Vòng tròn loading (CircularProgressIndicator)
                        SpinKitCubeGrid(color: Colors.white,size: 50.0,),
                       // const CircularProgressIndicator(color: Colors.amber,),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Lexend',
                            letterSpacing: 3.0,
                            decoration: TextDecoration.none,
                            shadows: [
                              Shadow(
                                blurRadius: 15.0,
                                color: Colors.black,
                                offset: Offset(0, 0),
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

  /// 2. ẨN LOADING
  static void hideLoadingIndicator(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// 3. THÔNG BÁO THÀNH CÔNG
  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green.shade700, Icons.check_circle);
  }

  /// 4. THÔNG BÁO LỖI
  static void showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red.shade800, Icons.error_outline, duration: 3);
  }

  /// 5. THÔNG BÁO BẢO TRÌ
  static void showMaintenanceSnackBar(BuildContext context) {
    _showSnackBar(context, 'Tính năng đang phát triển.', Colors.orange.shade800, Icons.engineering);
  }

  // Hàm private dùng chung
  static void _showSnackBar(BuildContext context, String message, Color bg, IconData icon, {int duration = 2}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: duration),
      ),
    );
  }
}