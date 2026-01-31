import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../utils/logger.dart';

// Import các file nội bộ trong dự án
import '../services/camera_service.dart';
import '../screens/camera_screen.dart';

/// HÀM MAIN: Điểm khởi đầu của ứng dụng.
/// Từ khóa 'async' cho phép sử dụng 'await' để chờ các tác vụ phần cứng khởi động.
void main() async {
  // 1. Đảm bảo các liên kết giữa Flutter và phần cứng thiết bị được khởi tạo hoàn tất trước khi chạy các lệnh tiếp theo.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Quan trọng: Cấu hình logging trước khi chạy ứng dụng
  setupLogging();

  // 3. Gọi hệ thống để lấy danh sách các ống kính camera hiện có trên điện thoại (Trước, sau, macro...)
  final cameras = await availableCameras();

  // Biến lưu trữ camera mà ứng dụng sẽ sử dụng
  CameraDescription? selectedCamera;

  // 4. Kiểm tra xem thiết bị có camera không (Đề phòng trường hợp máy hỏng camera hoặc máy ảo)
  if (cameras.isNotEmpty) {
    // Ưu tiên chọn camera đầu tiên trong danh sách (Thường là camera sau)
    selectedCamera = cameras.first;
  }

  // 5. Khởi chạy ứng dụng
  runApp(
    // Sử dụng Provider để "phát tín hiệu" CameraService ra toàn bộ ứng dụng.
    // Việc này giúp bất kỳ màn hình nào cũng có thể gọi các hàm điều khiển camera.
    ChangeNotifierProvider(
      create: (context) => CameraService(), // Tạo thực thể (instance) cho dịch vụ camera
      child: MyApp(camera: selectedCamera), // Khởi chạy Widget gốc MyApp
    ),
  );
}

/// WIDGET GỐC (ROOT WIDGET): Thiết lập cấu hình tổng thể cho ứng dụng
class MyApp extends StatelessWidget {
  final CameraDescription? camera; // Nhận thông tin camera từ hàm main chuyển vào

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    // TRƯỜNG HỢP LỖI: Nếu không tìm thấy bất kỳ camera nào trên máy
    if (camera == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text(
              'Không tìm thấy camera khả dụng trên thiết bị!',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    // TRƯỜNG HỢP CHÍNH: Khởi chạy giao diện chính của ứng dụng
    return MaterialApp(
      title: 'Bullet Counter', // Tên ứng dụng (hiện trong trình quản lý tác vụ)
      debugShowCheckedModeBanner: false, // Tắt chữ "Debug" ở góc màn hình cho đẹp

      // CẤU HÌNH GIAO DIỆN (THEME)
      theme: ThemeData(
        brightness: Brightness.dark, // Sử dụng chế độ nền tối (Dark mode) mặc định
        scaffoldBackgroundColor: Color(0xFF0F1115), // Màu nền chính là màu đen than (giảm mỏi mắt)
        useMaterial3: true, // Sử dụng ngôn ngữ thiết kế Material 3 mới nhất của Google

        // Cấu hình phông chữ hoặc màu sắc amber chủ đạo (nếu cần) có thể thêm ở đây
        colorSchemeSeed: Colors.amber,
      ),

      // Màn hình khởi đầu khi mở App: Màn hình Camera
      // Truyền thông tin camera đã chọn vào để màn hình này khởi động ống kính.
      home: CameraScreen(camera: camera!),
    );
  }
}