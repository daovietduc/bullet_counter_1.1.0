import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../services/camera_service.dart';
import '../widgets/camera_bottom_bar.dart';
import '../helpers/ui_helpers.dart';

/// [CameraScreen] là giao diện điều khiển camera chính của ứng dụng.
/// Màn hình này chịu trách nhiệm:
/// 1. Hiển thị luồng dữ liệu video thời gian thực (Camera Preview).
/// 2. Cung cấp các công cụ tương tác: Bật/tắt Flash, chụp ảnh.
/// 3. Hiển thị lớp phủ (Overlay) hướng dẫn người dùng căn chỉnh.
class CameraScreen extends StatefulWidget {
  /// Cấu hình camera được chọn (thường là camera sau).
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  /// Trạng thái điều khiển hiệu ứng "Shutter Flash" (màn hình chớp đen).
  /// Nhằm tạo phản hồi thị giác (Visual Feedback) giúp người dùng biết ảnh đã được chụp.
  bool _showFlashEffect = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo phần cứng thông qua Service.
    // Sử dụng [listen: false] vì không cần render lại Widget trong vòng đời khởi tạo.
    Provider.of<CameraService>(context, listen: false).initialize();
  }

  /// Kích hoạt hiệu ứng nháy màn hình mô phỏng cửa trập camera.
  /// Luồng hoạt động: [setState] bật đen -> Chờ 100ms -> [setState] tắt đen.
  void _triggerFlashEffect() {
    if (!mounted) return; // Đảm bảo widget còn tồn tại trong cây widget
    setState(() => _showFlashEffect = true);

    Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _showFlashEffect = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe các thay đổi trạng thái từ CameraService (FlashMode, Init status,...)
    final cameraService = Provider.of<CameraService>(context);

    // Xử lý trường hợp Camera đang nạp dữ liệu hoặc quyền truy cập chưa được cấp.
    if (!cameraService.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      /// --- TOP BAR: Điều khiển các thiết lập nhanh ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
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
            IconButton(
              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
              onPressed: () => UIHelper.showMaintenanceSnackBar(context),
            ),
          ],
        ),
      ),

      /// --- VIEWPORT: Khu vực hiển thị nội dung chính ---
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LỚP 1: Camera Preview.
          // Sử dụng FittedBox để xử lý sự khác biệt về Aspect Ratio giữa Sensor và Screen.
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // Hoán đổi Width/Height từ PreviewSize (Landscape) sang Portrait.
                width: cameraService.controller.value.previewSize!.height,
                height: cameraService.controller.value.previewSize!.width,
                child: CameraPreview(cameraService.controller),
              ),
            ),
          ),

          // LỚP 2: Viewfinder Overlay (Khung ngắm).
          // Dùng IgnorePointer để các tương tác chạm có thể truyền xuống lớp Preview phía dưới.
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

          // LỚP 3: Shutter Effect (Hiệu ứng chụp).
          // Sử dụng AnimatedOpacity để tạo cảm giác chuyển cảnh mượt mà thay vì bật/tắt tức thì.
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

      /// --- BOTTOM BAR: Hành động chính ---
      bottomNavigationBar: Container(
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CameraBottomBar(
              onTakePhoto: () async {
                _triggerFlashEffect(); // Tạo hiệu ứng thị giác ngay lập tức

                final service = Provider.of<CameraService>(context, listen: false);

                // Thực hiện quy trình: Chụp ảnh -> Xử lý -> Chuyển màn hình kết quả.
                // Hàm này sẽ 'await' cho đến khi người dùng quay lại từ màn hình kết quả.
                await service.takePictureAndNavigate(context);

                // Sau khi quay lại (Pop), kích hoạt lại camera để tiếp tục sử dụng.
                if (mounted) {
                  await service.resumeCamera();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// [CornersPainter] thực hiện vẽ 4 góc khung ngắm lên Canvas.
/// Giúp người dùng định vị mục tiêu vào vùng trung tâm của cảm biến.
class CornersPainter extends CustomPainter {
  final Color color;

  CornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 2.0;
    final double lineLength = size.width / 5;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
    // Góc: Trên - Trái
      ..moveTo(0, lineLength)
      ..lineTo(0, 0)
      ..lineTo(lineLength, 0)
    // Góc: Trên - Phải
      ..moveTo(size.width - lineLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, lineLength)
    // Góc: Dưới - Trái
      ..moveTo(0, size.height - lineLength)
      ..lineTo(0, size.height)
      ..lineTo(lineLength, size.height)
    // Góc: Dưới - Phải
      ..moveTo(size.width - lineLength, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - lineLength);

    canvas.drawPath(path, paint);
  }

  /// Không cần vẽ lại trừ khi cấu hình màu sắc thay đổi.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}