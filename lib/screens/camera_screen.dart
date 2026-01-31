import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../services/camera_service.dart';
import '../widgets/camera_bottom_toolbar.dart';
import '../helpers/ui_helpers.dart';

/// Màn hình camera chính để xem preview và chụp ảnh.
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Trạng thái cho hiệu ứng flash trên màn hình khi chụp.
  bool _showFlashEffect = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo camera service (listen: false vì đang ở trong initState).
    Provider.of<CameraService>(context, listen: false).initialize();
  }

  /// Kích hoạt hiệu ứng nháy màn hình khi chụp ảnh.
  void _triggerFlashEffect() {
    if (!mounted) return;
    setState(() => _showFlashEffect = true);
    // Tắt hiệu ứng sau một khoảng trễ ngắn để tạo animation.
    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _showFlashEffect = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe các thay đổi từ CameraService.
    final cameraService = Provider.of<CameraService>(context);

    // Hiển thị loading indicator trong khi chờ camera khởi tạo.
    if (!cameraService.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      // 1. App Bar: Chứa các điều khiển flash, tiêu đề, và các action khác.
      appBar: PreferredSize(
        // Đặt chiều cao cho toàn bộ khu vực AppBar
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          // Nút điều khiển flash.
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
              fontFamily: 'UTM_Helvet',
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: <Widget>[
            // Nút thay đổi tỷ lệ khung hình.
            IconButton(
              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
              onPressed: () => UIHelper.showMaintenanceSnackBar(context),
            ),
          ],
        ),
      ),

      // 2. Camera Preview: Hiển thị luồng video từ camera.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lớp 1: CameraPreview.
          // Dùng FittedBox để preview luôn fill đầy màn hình mà không bị méo.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // Kích thước preview của camera controller thường bị ngược W/H.
                width: cameraService.controller.value.previewSize!.height,
                height: cameraService.controller.value.previewSize!.width,
                child: CameraPreview(cameraService.controller),
              ),
            ),
          ),

          // Lớp 2: Overlay vẽ 4 góc khung ngắm.
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CustomPaint(
                  painter: CornersPainter(color: Colors.amber),
                ),
              ),
            ),
          ),

          // Lớp 3: Hiệu ứng flash (nháy đen màn hình).
          // AnimatedOpacity được dùng để tạo hiệu ứng fade-in/out mượt mà.
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

      // 3. Bottom Toolbar: Chứa nút chụp, thư viện và chuyển camera.
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.only(bottom: 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomToolbar(
              onTakePhoto: () {
                _triggerFlashEffect();
                // Yêu cầu service chụp ảnh và điều hướng (listen: false vì chỉ gọi hàm).
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

/// [CustomPainter] để vẽ 4 góc của khung ngắm camera.
class CornersPainter extends CustomPainter {
  final Color color;

  CornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Chiều dài mỗi góc (1/5 chiều rộng).
    final double lineLength = size.width / 5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path()
    // Top-left
      ..moveTo(0, lineLength)
      ..lineTo(0, 0)
      ..lineTo(lineLength, 0)
    // Top-right
      ..moveTo(size.width - lineLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, lineLength)
    // Bottom-left
      ..moveTo(0, size.height - lineLength)
      ..lineTo(0, size.height)
      ..lineTo(lineLength, size.height)
    // Bottom-right
      ..moveTo(size.width - lineLength, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - lineLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
