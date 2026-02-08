import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../services/camera_service.dart';
import '../widgets/camera_bottom_bar.dart';
import '../widgets/bullet_shape.dart';

/// [CameraScreen] là giao diện điều khiển camera chính của ứng dụng.
/// Màn hình này chịu trách nhiệm:
/// 1. Hiển thị luồng dữ liệu video thời gian thực (Camera Preview).
/// 2. Cung cấp các công cụ tương tác: Bật/tắt Flash, chụp ảnh.
/// 3. Hiển thị lớp phủ (Overlay) hướng dẫn người dùng căn chỉnh.

/// 1. ĐỊNH NGHĨA CÁC TỶ LỆ KHUNG HÌNH HỖ TRỢ
/// Giúp quản lý các chế độ khung hình khác nhau mà người dùng có thể chọn.
enum CameraRatio { ratio3_4, ratio1_1}

extension CameraRatioExtension on CameraRatio {
  /// Trả về giá trị số thực để tính toán Widget AspectRatio.
  double get value {
    switch (this) {
      case CameraRatio.ratio3_4: return 3 / 4;
      case CameraRatio.ratio1_1: return 1 / 1;
    }
  }

  /// Nhãn hiển thị tương ứng trên nút bấm ở AppBar.
  String get label {
    switch (this) {
      case CameraRatio.ratio3_4: return "3:4";
      case CameraRatio.ratio1_1: return "1:1";
    }
  }
}

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

  /// 2. Biến trạng thái lưu trữ tỷ lệ khung hình hiện tại.
  CameraRatio _selectedRatio = CameraRatio.ratio3_4;

  @override
  void initState() {
    super.initState();
    // Khởi tạo phần cứng thông qua Service.
    // Sử dụng [listen: false] vì không cần render lại Widget trong vòng đời khởi tạo.
    Provider.of<CameraService>(context, listen: false).initialize();
  }

  /// 3. Hàm chuyển đổi tỷ lệ khung hình theo vòng lặp (3:4 -> 1:1 -> FULL).
  void _toggleRatio() {
    setState(() {
      int nextIndex = (_selectedRatio.index + 1) % CameraRatio.values.length;
      _selectedRatio = CameraRatio.values[nextIndex];
    });
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

    // Xác định tỷ lệ mục tiêu dựa trên lựa chọn của người dùng.
    double targetAspectRatio = _selectedRatio.value;

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
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: _toggleRatio,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    // Hình chữ nhật có chiều ngang rộng hơn chiều cao một chút
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40), // Nền mờ hiện đại
                      borderRadius: BorderRadius.circular(6.0), // Bo góc nhẹ (Rectangle)
                      border: Border.all(
                        color: Colors.white54,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      _selectedRatio.label,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w800, // Làm đậm hơn để dễ đọc
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      /// --- VIEWPORT: Khu vực hiển thị nội dung chính ---
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lớp nền đen toàn màn hình làm nền cho khung chụp.
          Container(color: Colors.black),

          // CỤM CAMERA & OVERLAY: Căn giữa màn hình và co giãn theo tỷ lệ đã chọn.
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300), // Tạo hiệu ứng chuyển đổi tỷ lệ mượt mà.
              curve: Curves.easeInOut,
              child: AspectRatio(
                aspectRatio: targetAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // LỚP 1: Camera Preview.
                    // Sử dụng FittedBox để luồng video luôn lấp đầy khung hình mà không bị méo.
                    ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: cameraService.controller.value.previewSize!.height,
                          height: cameraService.controller.value.previewSize!.width,
                          child: CameraPreview(cameraService.controller),
                        ),
                      ),
                    ),

                    // LỚP 2: Vẽ hình viên đạn trên Camera Preview.
                    // Sử dụng IgnorePointer để các tương tác chạm không bị cản trở bởi lớp vẽ này.
                    Positioned(
                      left: 23, // Cách lề trái khung chụp 20 đơn vị
                      bottom: 50, // Cách lề dưới khung chụp 20 đơn vị
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: BulletShape(),
                        ),
                      ),
                    ),

                    // LỚP 3: Khung ngắm định vị.
                    // Sử dụng IgnorePointer để các tương tác chạm không bị cản trở bởi lớp vẽ này.
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CustomPaint(
                          painter: CornersPainter(color: Colors.amber),
                        ),
                      ),
                    ),

                    // LỚP 4: Shutter Effect.
                    // Hiển thị lớp đen mờ khi chụp ảnh để tạo hiệu ứng màn trập.
                    AnimatedOpacity(
                      opacity: _showFlashEffect ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 100),
                      child: IgnorePointer(child: Container(color: Colors.black)),
                    ),
                  ],
                ),
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
                _triggerFlashEffect(); // Tạo hiệu ứng thị giác ngay lập tức.
                double currentRatio = _selectedRatio.value; // Tỷ lệ khung hình.
                final service = Provider.of<CameraService>(context, listen: false);

                // Thực hiện quy trình: Chụp ảnh -> Xử lý -> Chuyển màn hình kết quả.
                await service.takePictureAndNavigate(context, currentRatio);

                // Sau khi quay lại màn hình này (Pop), kích hoạt lại camera để tiếp tục sử dụng.
                if (mounted) {await service.resumeCamera();}
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
    final double lineLength = size.width / 5; // Độ dài đoạn thẳng góc bằng 1/5 chiều rộng.

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