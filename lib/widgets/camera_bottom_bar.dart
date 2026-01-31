import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/counting_screen.dart';
import '../helpers/ui_helpers.dart';

/// [CameraBottomBar] là thanh điều khiển phía dưới của màn hình Camera.
/// Nó bao gồm 3 chức năng chính: Truy cập thư viện ảnh, Chụp ảnh mới, và Xem lịch sử.
class CameraBottomBar extends StatefulWidget {
  /// Callback thực thi hành động chụp ảnh (thường gọi đến CameraController ở màn hình cha).
  final VoidCallback onTakePhoto;

  const CameraBottomBar({super.key, required this.onTakePhoto});

  @override
  State<CameraBottomBar> createState() => _CameraBottomBarState();
}

class _CameraBottomBarState extends State<CameraBottomBar> {
  /// Trạng thái theo dõi quá trình mở thư viện để hiển thị Loading Spinner.
  bool _isPickingImage = false;

  /// Xử lý logic chọn ảnh từ thư viện của thiết bị.
  Future<void> _pickImageFromGallery(BuildContext context) async {
    // Chặn hành động nếu đang trong quá trình xử lý ảnh trước đó.
    if (_isPickingImage) return;

    try {
      setState(() {
        _isPickingImage = true;
      });

      final ImagePicker picker = ImagePicker();

      // [TỐI ƯU HÓA HIỆU SUẤT]:
      // Giới hạn kích thước ảnh (1024x1024) và chất lượng (85%) ngay khi chọn.
      // Điều này giúp tiết kiệm bộ nhớ RAM khi AI xử lý và giảm nguy cơ lỗi Crash (Out of Memory).
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      // Kiểm tra tính hợp lệ của Context (đề phòng người dùng đã thoát màn hình khi đang chọn).
      if (!context.mounted || pickedFile == null) return;

      // Điều hướng người dùng sang màn hình kết quả kèm theo đường dẫn ảnh đã chọn.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountingScreen(imagePath: pickedFile.path),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        UIHelper.showErrorSnackBar(context, 'Lỗi mở thư viện: $e');
      }
    } finally {
      // Đảm bảo trạng thái Loading được tắt dù thành công hay thất bại.
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Màu nền đen đặc trưng của giao diện nhiếp ảnh.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            // Padding dưới (32.0) thường được dùng để tránh đè lên thanh Home của iOS/Android.
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _buildAlbumButton(context),   // Nút Thư viện (Trái)
                _buildCaptureButton(),        // Nút Chụp (Giữa)
                _buildHistoryButton(context), // Nút Lịch sử (Phải)
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nút mở Album ảnh: Có tích hợp hiệu ứng Loading khi đang xử lý.
  Widget _buildAlbumButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImageFromGallery(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50), // Hiệu ứng làm mờ nhẹ (Frosted glass).
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: _isPickingImage
            ? const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: Colors.amber,
              strokeWidth: 3.0,
            ),
          ),
        )
            : const Icon(
          Icons.photo_library,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// Nút Chụp ảnh: Thiết kế theo tiêu chuẩn Camera truyền thống (Vòng tròn lồng nhau).
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: widget.onTakePhoto,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4.0, // Viền ngoài dày tạo điểm nhấn.
          ),
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  /// Nút Lịch sử: Hiện tại đang để chế độ chờ phát triển (Maintenance).
  Widget _buildHistoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        UIHelper.showMaintenanceSnackBar(context);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.history,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}