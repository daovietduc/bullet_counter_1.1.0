import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../screens/counting_screen.dart';
import 'package:logging/logging.dart';

/// [CameraService] đóng vai trò là "Trái tim" điều hành mọi nghiệp vụ liên quan đến hình ảnh.
/// Lợi ích của việc tách biệt Logic Camera ra khỏi Widget:
/// * **Tính tái sử dụng**: Có thể gọi các hàm camera từ bất kỳ đâu thông qua Provider.
/// * **Hiệu năng**: Quản lý vòng đời khởi tạo/giải phóng camera độc lập với việc Build lại giao diện.
/// * **Dễ kiểm thử**: Có thể viết Unit Test cho Logic chụp ảnh mà không cần UI.
class CameraService extends ChangeNotifier {

  // --- 1. QUẢN LÝ TRẠNG THÁI (STATE MANAGEMENT) ---

  /// Đối tượng cốt lõi để giao tiếp với API Camera của hệ điều hành (Android/iOS).
  late CameraController _cameraController;

  /// Đối tượng [Future] để đồng bộ hóa quá trình khởi tạo.
  /// Đảm bảo các lệnh điều khiển chỉ được thực thi khi phần cứng đã sẵn sàng.
  late Future<void> initializeControllerFuture;

  /// Danh sách các cảm biến ảnh phát hiện được trên thiết bị.
  List<CameraDescription> _cameras = [];

  /// Lưu trữ chế độ Flash hiện tại để đồng bộ trạng thái Icon trên giao diện.
  FlashMode _currentFlashMode = FlashMode.off;

  /// Cờ bảo vệ (Guard flag) để ngăn chặn việc truy cập vào controller khi chưa khởi tạo xong.
  bool _isInitialized = false;

  /// Hệ thống ghi nhật ký (Logging) giúp truy vết lỗi trong môi trường Production.
  final _log = Logger('CameraService');

  // --- 2. CÁC HÀM TRUY XUẤT (GETTERS) ---

  CameraController get controller => _cameraController;
  FlashMode get currentFlashMode => _currentFlashMode;
  bool get isInitialized => _isInitialized;

  // --- 3. QUY TRÌNH KHỞI TẠO (LIFECYCLE INITIALIZATION) ---

  /// Thiết lập kết nối giữa ứng dụng và phần cứng Camera.
  /// Quy trình thực hiện:
  /// 1. Quét danh sách phần cứng -> 2. Khởi tạo cấu hình -> 3. Kích hoạt cảm biến.
  Future<void> initialize() async {
    try {
      // Xác định các camera khả dụng trên thiết bị (Trước/Sau/Góc rộng).
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _log.severe("Không tìm thấy camera trên thiết bị này.");
        return;
      }

      // Khởi tạo controller với Camera mặc định (thường là camera sau - index 0).
      // [ResolutionPreset.high]: Cân bằng tốt nhất giữa độ chi tiết ảnh cho AI
      // và mức độ tiêu thụ RAM/Pin của thiết bị.
      _cameraController = CameraController(
        _cameras[0],
        ResolutionPreset.high,
        enableAudio: false, // Tắt ghi âm để tránh yêu cầu quyền 'Microphone' không cần thiết.
      );

      // Bắt đầu tiến trình khởi tạo phần cứng (Bật cảm biến, ống kính).
      initializeControllerFuture = _cameraController.initialize();
      await initializeControllerFuture;

      // Thiết lập các thông số ban đầu để tối ưu cho việc quét vật thể.
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto); // Chế độ lấy nét tự động liên tục.

      _isInitialized = true;
      _log.info("Camera đã khởi tạo và sẵn sàng hoạt động.");

      // Thông báo cho các Consumer (Widgets) đang lắng nghe để render Preview.
      notifyListeners();
    } catch (e, stackTrace) {
      _log.shout("Lỗi nghiêm trọng khi khởi tạo camera: $e", e, stackTrace);
    }
  }

  // --- 4. CÁC HÀNH ĐỘNG ĐIỀU KHIỂN (ACTIONS) ---

  /// Thực hiện chụp ảnh và chuyển tiếp dữ liệu đến màn hình xử lý [CountingScreen].
  /// Luồng xử lý bất đồng bộ:
  /// - Chụp ảnh -> Lưu file tạm -> Dừng Camera (Tiết kiệm tài nguyên) -> Chuyển trang.
  Future<void> takePictureAndNavigate(BuildContext context, double appliedRatio) async {
    // Ngăn chặn nhấn nút liên tục khi đang xử lý ảnh cũ.
    if (!_isInitialized || _cameraController.value.isTakingPicture) return;

    try {
      // Bước 1: Ghi lại hình ảnh từ luồng stream hiện tại vào một file tạm thời (XFile).
      final XFile image = await _cameraController.takePicture();

      // Bước 2: Tạm dừng luồng Video Preview.
      // Điều này cực kỳ quan trọng vì màn hình CountingScreen có thể sử dụng AI
      // (TensorFlow/PyTorch) gây tốn nhiều tài nguyên GPU.
      await _cameraController.pausePreview();
      _log.info("Đã tạm dừng Camera để ưu tiên tài nguyên cho xử lý AI.");

      // Bước 3: Điều hướng người dùng sang màn hình kết quả.
      if (context.mounted) {
        // Chờ đợi (await) cho đến khi người dùng đóng màn hình CountingScreen.
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CountingScreen(imagePath: image.path, aspectRatio: appliedRatio),
          ),
        );

        _log.info("Người dùng đã quay trở lại màn hình chính.");
      }
    } catch (e) {
      _log.severe("Lỗi trong quá trình chụp ảnh/điều hướng: $e", e);
    }
  }

  /// Thay đổi chế độ đèn Flash (Chỉ hỗ trợ Off và Always - Chế độ Torch).
  void toggleFlashMode() async {
    if (!_isInitialized) return;

    final newMode = _currentFlashMode == FlashMode.off ? FlashMode.always : FlashMode.off;

    try {
      await _cameraController.setFlashMode(newMode);
      _currentFlashMode = newMode;

      // Kích hoạt UI render lại để cập nhật màu sắc/icon của nút Flash.
      notifyListeners();
    } catch (e, stackTrace) {
      _log.severe("Không thể thay đổi chế độ Flash: $e", e, stackTrace);
    }
  }

  /// Tạm dừng luồng hình ảnh trực tiếp (Dùng khi chuyển tab hoặc vào Settings).
  Future<void> pauseCamera() async {
    if (!_isInitialized) return;
    try {
      await _cameraController.pausePreview();
      _log.info("Luồng Preview đã tạm nghỉ.");
    } catch (e) {
      _log.severe("Lỗi khi pause camera: $e");
    }
  }

  /// Kích hoạt lại luồng hình ảnh trực tiếp.
  Future<void> resumeCamera() async {
    if (!_isInitialized) return;
    try {
      await _cameraController.resumePreview();
      _log.info("Luồng Preview đã hoạt động trở lại.");
    } catch (e) {
      _log.severe("Lỗi khi resume camera: $e");
    }
  }

  // --- 5. GIẢI PHÓNG (RESOURCE CLEANUP) ---

  @override
  void dispose() {
    /// Lưu ý quan trọng: Camera là tài nguyên dùng chung của hệ thống.
    /// Nếu không giải phóng, ứng dụng sẽ rò rỉ bộ nhớ (Memory Leak)
    /// và có thể khóa quyền truy cập camera của các ứng dụng khác.
    _cameraController.dispose();
    super.dispose();
  }
}