import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../screens/counting_screen.dart';
import '../helpers/ui_helpers.dart';

// Đã chuyển thành StatefulWidget để quản lý trạng thái tải khi mở thư viện.
class BottomToolbar extends StatefulWidget {
  /// Callback được gọi khi người dùng nhấn nút chụp ảnh.
  final VoidCallback onTakePhoto;

  const BottomToolbar({super.key, required this.onTakePhoto});

  @override
  State<BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends State<BottomToolbar> {
  // Biến trạng thái để theo dõi quá trình mở thư viện ảnh.
  bool _isPickingImage = false;

  /// Mở thư viện và cho phép người dùng chọn một ảnh.
  /// Hiển thị chỉ báo tải để cải thiện trải nghiệm người dùng.
  Future<void> _pickImageFromGallery(BuildContext context) async {
    // Ngăn người dùng nhấn nhiều lần khi đang xử lý.
    if (_isPickingImage) return;

    try {
      // Cập nhật UI để hiển thị loading ngay lập tức.
      setState(() {
        _isPickingImage = true;
      });

      final ImagePicker picker = ImagePicker();
      // [TỐI ƯU HÓA] Yêu cầu picker giảm kích thước ảnh trước khi trả về.
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      // Thoát nếu context không còn hợp lệ hoặc người dùng không chọn ảnh.
      if (!context.mounted || pickedFile == null) return;

      // Điều hướng đến màn hình đếm với ảnh đã chọn.
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
      // Luôn đảm bảo ẩn loading khi quá trình kết thúc.
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
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Chỉ chiếm không gian cần thiết.
        children: <Widget>[
          // Thêm padding để tạo khoảng trống an toàn và cân đối.
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Căn đều các phần tử.
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _buildAlbumButton(context),   // Nút mở thư viện ảnh.
                _buildCaptureButton(),        // Nút chụp ảnh chính.
                _buildHistoryButton(context), // Nút xem lịch sử.
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget cho nút mở thư viện ảnh với chỉ báo tải.
  Widget _buildAlbumButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickImageFromGallery(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          borderRadius: BorderRadius.circular(8.0),
        ),
        // Hiển thị vòng xoay tải hoặc icon tùy thuộc vào trạng thái.
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

  /// Widget cho nút chụp ảnh.
  Widget _buildCaptureButton() {
    return GestureDetector(
      // Gọi callback onTakePhoto từ widget cha thông qua 'widget.'.
      onTap: widget.onTakePhoto,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          // Viền ngoài.
          border: Border.all(
            color: Colors.white,
            width: 4.0,
          ),
        ),
        // Vòng tròn trắng bên trong.
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

  /// Widget cho nút lịch sử (hiện đang hiển thị thông báo bảo trì).
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
