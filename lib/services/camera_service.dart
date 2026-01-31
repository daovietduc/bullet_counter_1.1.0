import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../screens/counting_screen.dart';
import 'package:logging/logging.dart';

/// [CameraService] quản lý toàn bộ vòng đời và hoạt động của Camera.
/// Sử dụng [ChangeNotifier] để thông báo cho UI cập nhật khi trạng thái camera thay đổi
/// (ví dụ: khi camera khởi tạo xong hoặc khi đổi chế độ Flash).
class CameraService extends ChangeNotifier {

  // --- 1. TRẠNG THÁI (STATE) ---

  /// [CameraController] là đối tượng điều khiển chính để truy cập vào luồng dữ liệu camera.
  late CameraController _cameraController;

  /// Future dùng để theo dõi trạng thái bất đồng bộ của quá trình khởi tạo.
  /// Giúp UI biết khi nào nên hiển thị 'Loading' và khi nào hiển thị 'Preview'.
  late Future<void> initializeControllerFuture;

  /// Lưu trữ danh sách các ống kính có sẵn (trước, sau, góc rộng...).
  List<CameraDescription> _cameras = [];

  /// Trạng thái đèn Flash hiện tại.
  FlashMode _currentFlashMode = FlashMode.off;

  /// Cờ kiểm tra trạng thái sẵn sàng để tránh gọi lệnh khi camera chưa nạp xong.
  bool _isInitialized = false;

  /// Logger giúp theo dõi lịch sử hoạt động và bắt lỗi trong quá trình vận hành.
  final _log = Logger('CameraService');

  // --- 2. CÁC HÀM TRUY XUẤT (GETTERS) ---

  CameraController get controller => _cameraController;
  FlashMode get currentFlashMode => _currentFlashMode;
  bool get isInitialized => _isInitialized;

  // --- 3. KHỞI TẠO (INITIALIZATION) ---

  /// Hàm [initialize] thiết lập kết nối giữa ứng dụng và phần cứng camera.
  Future<void> initialize() async {
    try {
      // Bước 1: Hỏi hệ điều hành danh sách camera khả dụng.
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _log.severe("Không tìm thấy camera trên thiết bị này.");
        return;
      }

      // Bước 2: Khởi tạo controller.
      // ResolutionPreset.high (720p/1080p) là lựa chọn tối ưu:
      // Đủ nét để AI nhận diện vật thể nhỏ nhưng không quá nặng làm lag UI.
      _cameraController = CameraController(
        _cameras[0], // Mặc định chọn camera sau.
        ResolutionPreset.high,
        enableAudio: false, // Tắt audio giúp tiết kiệm tài nguyên và quyền truy cập.
      );

      // Bước 3: Kích hoạt camera.
      initializeControllerFuture = _cameraController.initialize();
      await initializeControllerFuture;

      // Bước 4: Thiết lập cấu hình mặc định ban đầu.
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto); // Tự động lấy nét.

      _isInitialized = true;
      _log.info("Camera đã khởi tạo thành công.");

      // Cập nhật cho các Widget đang lắng nghe (ví dụ: CameraPreview).
      notifyListeners();
    } catch (e, stackTrace) {
      _log.shout("Lỗi nghiêm trọng khi khởi tạo camera", e, stackTrace);
    }
  }

  // --- 4. CÁC HÀNH ĐỘNG (ACTIONS) ---

  /// Chụp ảnh và chuyển hướng dữ liệu sang màn hình xử lý AI.
  Future<void> takePictureAndNavigate(BuildContext context) async {
    // Chặn hành động nếu camera chưa sẵn sàng.
    if (!isInitialized) return;

    try {
      // Chụp ảnh và lưu vào bộ nhớ tạm (Temporary Directory).
      final XFile imageFile = await _cameraController.takePicture();

      // Kiểm tra tính hợp lệ của context trước khi điều hướng trang.
      if (!context.mounted) return;

      // Chuyển sang màn hình CountingScreen.
      // Chỉ truyền Path (String) để tối ưu hiệu suất thay vì truyền cả file ảnh lớn.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: imageFile.path),
        ),
      );
    } catch (e, stackTrace) {
      _log.severe('Lỗi khi chụp ảnh', e, stackTrace);
    }
  }

  /// Chuyển đổi trạng thái đèn Flash giữa Tắt và Luôn bật (Torch).
  void toggleFlashMode() async {
    if (!_isInitialized) return;

    // Logic chuyển đổi đơn giản: Nếu đang tắt thì bật, và ngược lại.
    final newMode = _currentFlashMode == FlashMode.off ? FlashMode.always : FlashMode.off;

    try {
      await _cameraController.setFlashMode(newMode);
      _currentFlashMode = newMode;

      // Thông báo để UI thay đổi icon đèn Flash tương ứng.
      notifyListeners();
    } catch (e, stackTrace) {
      _log.severe("Lỗi khi thiết lập chế độ Flash", e, stackTrace);
    }
  }

  // --- 5. GIẢI PHÓNG TÀI NGUYÊN (LIFECYCLE) ---

  @override
  void dispose() {
    // CỰC KỲ QUAN TRỌNG: Phải đóng luồng camera khi không sử dụng.
    // Nếu không, camera sẽ bị treo, gây nóng máy và các app khác không thể truy cập camera.
    _cameraController.dispose();
    super.dispose();
  }
}