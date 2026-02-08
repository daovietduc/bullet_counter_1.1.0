import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../screens/counting_screen.dart';
import '../helpers/ui_helpers.dart';
import '../services/camera_service.dart';

/// [CameraBottomBar] là bảng điều khiển tác vụ chính tại màn hình chụp ảnh.
/// Widget này chịu trách nhiệm:
/// 1. Cung cấp nút chụp ảnh trung tâm (Shutter button).
/// 2. Kết nối với thư viện ảnh hệ thống (Gallery) để xử lý ảnh có sẵn.
/// 3. Truy cập lịch sử quét (Tính năng đang phát triển).
class CameraBottomBar extends StatefulWidget {
  /// Callback thực thi hành động chụp ảnh từ Camera trực tiếp.
  /// Được truyền từ [CameraScreen] để tương tác với Controller chính.
  final VoidCallback onTakePhoto;

  const CameraBottomBar({super.key, required this.onTakePhoto});

  @override
  State<CameraBottomBar> createState() => _CameraBottomBarState();
}

class _CameraBottomBarState extends State<CameraBottomBar> {
  /// Cờ trạng thái (Flag) để quản lý quá trình truy xuất tệp tin.
  /// Giúp ngăn chặn việc người dùng nhấn liên tục gây lỗi "Multiple Intents".
  bool _isPickingImage = false;
  bool _isPressed = false;

  /// Điều phối quy trình chọn ảnh từ thư viện và điều hướng xử lý.
  /// Quy trình gồm 4 giai đoạn an toàn:
  /// - **Giai đoạn 1**: Tạm dừng luồng Camera để tối ưu hóa tài nguyên hệ thống.
  /// - **Giai đoạn 2**: Gọi Intent hệ thống mở trình chọn ảnh.
  /// - **Giai đoạn 3**: Kiểm tra tính hợp lệ của tệp tin được chọn.
  /// - **Giai đoạn 4**: Điều hướng sang màn hình đếm và khôi phục camera khi quay lại.
  Future<void> _pickImageFromGallery(BuildContext context) async {
    if (_isPickingImage) return;

    // Truy xuất CameraService mà không lắng nghe thay đổi (listen: false)
    // để thực hiện các lệnh điều khiển luồng.
    final cameraService = Provider.of<CameraService>(context, listen: false);

    try {
      setState(() => _isPickingImage = true);

      final ImagePicker picker = ImagePicker();

      // Mở trình chọn ảnh với cấu hình tối ưu cho AI:
      // Giới hạn kích thước giúp tăng tốc độ nạp ảnh vào RAM tại màn hình sau.
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85, // Cân bằng giữa dung lượng tệp và độ chi tiết vật thể.
      );

      // Xử lý khi người dùng hủy chọn ảnh (nhấn nút Back hệ thống).
      if (pickedFile == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      if (!context.mounted) return;

      // Tạm dừng Preview: Tránh việc CPU phải render video nền khi người dùng đang ở Gallery.
      // Đồng thời giảm thiểu nguy cơ xung đột phần cứng trên một số dòng máy Android cũ.
      await cameraService.pauseCamera();

      // Chuyển sang màn hình xử lý kết quả.
      // await ở đây giữ cho tiến trình chờ đợi cho đến khi CountingScreen được 'Pop'.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(
              imagePath: pickedFile.path,
              aspectRatio: 1,
              isFromAlbum: true,
          ),
        ),
      );

      // Tái kích hoạt luồng camera khi quay lại màn hình chính.
      await cameraService.resumeCamera();

    } catch (e) {
      // Đảm bảo camera luôn được khôi phục dù có lỗi xảy ra trong quá trình chọn tệp.
      await cameraService.resumeCamera();
      if (context.mounted) {
        UIHelper.showErrorSnackBar(context, 'Lỗi truy cập thư viện: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Tạo sự tương phản mạnh giúp nổi bật khu vực điều khiển.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            // Căn chỉnh khoảng cách an toàn (Safe Area) cho các thiết bị có tai thỏ/cằm dày.
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _buildAlbumButton(context),
                _buildCaptureButton(),
                _buildHistoryButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nút chức năng mở Album: Thiết kế dạng ô vuông bo góc.
  Widget _buildAlbumButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImageFromGallery(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          borderRadius: BorderRadius.circular(12.0), // Bo góc hiện đại hơn.
        ),
        child: _isPickingImage
            ? const Center(
          child: SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              color: Colors.amber,
              strokeWidth: 2.5,
            ),
          ),
        )
            : const Icon(
          Icons.photo_library_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// Nút Chụp ảnh chính (Shutter Button).
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTakePhoto,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 5.0, // Viền ngoài cố định
          ),
        ),
        child: Center(
          // Chỉ phần lõi trắng này là co giãn
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: _isPressed ? 54 : 62,
            height: _isPressed ? 54 : 62,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// Nút Lịch sử: Truy cập danh sách các lần đếm trước đây.
  Widget _buildHistoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () => UIHelper.showMaintenanceSnackBar(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.history_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}