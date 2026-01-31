import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../services/camera_service.dart';
import '../widgets/camera_bottom_bar.dart';
import '../helpers/ui_helpers.dart';

/// [CameraScreen] là màn hình giao diện chính khi người dùng mở ứng dụng.
/// Nó hiển thị luồng video trực tiếp từ ống kính và cung cấp các nút điều khiển chụp.
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  /// Trạng thái điều khiển hiệu ứng "chớp đen" khi nhấn nút chụp.
  /// Giúp người dùng nhận biết được ảnh đã được ghi lại thành công (Visual Feedback).
  bool _showFlashEffect = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo phần cứng camera ngay khi màn hình vừa được nạp vào bộ nhớ.
    // listen: false được dùng vì ta chỉ gọi hàm, không muốn build lại cả widget ở đây.
    Provider.of<CameraService>(context, listen: false).initialize();
  }

  /// Kích hoạt hiệu ứng nháy màn hình mô phỏng cửa trập camera.
  void _triggerFlashEffect() {
    if (!mounted) return;
    setState(() => _showFlashEffect = true);

    // Sử dụng Timer để tự động tắt lớp màu đen sau 100ms.
    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _showFlashEffect = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Đăng ký lắng nghe sự thay đổi từ CameraService (như FlashMode, Initialization status).
    final cameraService = Provider.of<CameraService>(context);

    // 1. KIỂM TRA TRẠNG THÁI: Nếu camera chưa sẵn sàng, hiển thị màn hình chờ.
    if (!cameraService.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      // --- PHẦN 1: THANH CÔNG CỤ TRÊN (APP BAR) ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          // Nút điều khiển đèn Flash: Thay đổi icon và màu sắc dựa trên mode hiện tại.
          leading: IconButton(
            icon: Icon(
              cameraService.currentFlashMode == FlashMode.off
                  ? Icons.flash_off
                  : Icons.flash_on,
              color: cameraService.currentFlashMode == FlashMode.off
                  ? Colors.white
                  : Colors.yellow,
            ),
            onPressed: cameraService.toggleFlashMode,
          ),
          title: const Text(
            'BULLET COUNTER',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'UTM_Helvet', // Font chữ tùy chỉnh tạo nét chuyên nghiệp
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: <Widget>[
            // Nút cấu hình tỷ lệ khung hình (Hiện tại đang để chế độ chờ bảo trì).
            IconButton(
              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
              onPressed: () => UIHelper.showMaintenanceSnackBar(context),
            ),
          ],
        ),
      ),

      // --- PHẦN 2: KHU VỰC HIỂN THỊ CAMERA (BODY) ---
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LỚP 1: Luồng Video trực tiếp (Camera Preview).
          // Sử dụng FittedBox để giải quyết vấn đề tỷ lệ khung hình giữa cảm biến ảnh và màn hình điện thoại.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover, // Đảm bảo ảnh tràn toàn bộ khu vực hiển thị.
              child: SizedBox(
                // Lưu ý: PreviewSize thường trả về Width/Height theo chiều ngang của cảm biến.
                // Do đó, khi ở chế độ dọc (Portrait), ta phải hoán đổi chúng.
                width: cameraService.controller.value.previewSize!.height,
                height: cameraService.controller.value.previewSize!.width,
                child: CameraPreview(cameraService.controller),
              ),
            ),
          ),

          // LỚP 2: Khung ngắm (Viewfinder Overlay).
          // Vẽ 4 góc màu vàng giúp người dùng căn chỉnh vật thể vào trung tâm ảnh.
          Positioned.fill(
            child: IgnorePointer( // Cho phép các sự kiện chạm xuyên qua lớp này.
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CustomPaint(
                  painter: CornersPainter(color: Colors.amber),
                ),
              ),
            ),
          ),

          // LỚP 3: Hiệu ứng Flash giả lập (Screen Flash).
          // Khi chụp, lớp đen này sẽ mờ dần rồi biến mất trong 100ms.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showFlashEffect ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: IgnorePointer(
                child: Container(color: Colors.black),
              ),
            ),
          ),
        ],
      ),

      // --- PHẦN 3: THANH ĐIỀU KHIỂN DƯỚI (BOTTOM BAR) ---
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CameraBottomBar(
              onTakePhoto: () {
                // Thực hiện đồng thời 2 hành động: Hiệu ứng nháy và Chụp ảnh.
                _triggerFlashEffect();
                Provider.of<CameraService>(context, listen: false)
                    .takePictureAndNavigate(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// [CornersPainter] vẽ 4 đường kẻ góc đặc trưng của các thiết bị ngắm/quét.
class CornersPainter extends CustomPainter {
  final Color color;

  CornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double lineLength = size.width / 5; // Độ dài của mỗi nét vẽ góc.
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()
    // Vẽ góc trên bên trái
      ..moveTo(0, lineLength)
      ..lineTo(0, 0)
      ..lineTo(lineLength, 0)
    // Vẽ góc trên bên phải
      ..moveTo(size.width - lineLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, lineLength)
    // Vẽ góc dưới bên trái
      ..moveTo(0, size.height - lineLength)
      ..lineTo(0, size.height)
      ..lineTo(lineLength, size.height)
    // Vẽ góc dưới bên phải
      ..moveTo(size.width - lineLength, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - lineLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}