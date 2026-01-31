import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// [DisplayOptions] là một Widget dạng Drawer (thanh kéo từ cạnh màn hình).
/// Widget này cung cấp giao diện để người dùng tùy chỉnh cách hiển thị kết quả AI,
/// bao gồm việc bật/tắt các lớp vẽ (overlays) và thay đổi thẩm mỹ của chúng.
class DisplayOptions extends StatelessWidget {
  // --- CÁC TRẠNG THÁI HIỂN THỊ HIỆN TẠI ---
  final bool showBoundingBoxes; // Hiển thị khung bao quanh vật thể
  final bool showConfidence;    // Hiển thị % độ tin cậy của AI
  final bool showFillBox;       // Có tô màu vào bên trong khung bao hay không
  final bool showOrderNumber;   // Hiển thị số thứ tự (1, 2, 3...) cho từng vật thể
  final bool isMultiColor;      // Bật chế độ mỗi vật thể một màu ngẫu nhiên
  final double fillOpacity;     // Mức độ đậm nhạt của màu nền khung (0.0 -> 1.0)
  final Color boxColor;         // Màu sắc chủ đạo của khung bao

  /// Callback [onOptionChanged] dùng để thông báo cho màn hình cha cập nhật State.
  /// [key]: Tên thuộc tính cần thay đổi (vd: 'box', 'opacity').
  /// [value]: Giá trị mới của thuộc tính đó.
  final Function(String key, dynamic value) onOptionChanged;

  const DisplayOptions({
    super.key,
    required this.showBoundingBoxes,
    required this.showConfidence,
    required this.showFillBox,
    required this.showOrderNumber,
    required this.isMultiColor,
    required this.fillOpacity,
    required this.boxColor,
    required this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // Độ rộng Drawer chiếm 75% chiều rộng màn hình
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: const Color(0xFFF2F2F7), // Màu nền xám nhạt đặc trưng của iOS
      child: Column(
        children: [
          _buildHeader(context), // Thanh tiêu đề trên cùng
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionTitle('CÀI ĐẶT HIỂN THỊ'),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildToggleItem(
                        label: 'Bounding Box',
                        icon: Icons.crop_free,
                        value: showBoundingBoxes,
                        onChanged: (val) => onOptionChanged('box', val),
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Tô màu khung',
                        icon: Icons.format_color_fill,
                        value: showFillBox,
                        onChanged: (val) => onOptionChanged('fill', val),
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Đa màu sắc',
                        icon: Icons.palette_outlined,
                        value: isMultiColor,
                        onChanged: (val) => onOptionChanged('multiColor', val),
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Số thứ tự',
                        icon: Icons.format_list_numbered,
                        value: showOrderNumber,
                        onChanged: (val) => onOptionChanged('order', val),
                      ),
                      _buildDivider(),
                      _buildToggleItem(
                        label: 'Độ tin cậy',
                        icon: Icons.percent,
                        value: showConfidence,
                        onChanged: (val) => onOptionChanged('confidence', val),
                      ),
                    ],
                  ),
                ),

                _buildSectionTitle('TÙY CHỈNH NÂNG CAO'),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildColorPickerItem(
                        label: 'Màu sắc khung',
                        currentColor: boxColor,
                        onTap: () => _showColorPickerDialog(context),
                      ),
                      _buildDivider(),
                      _buildOpacityPickerItem(
                        label: 'Độ trong suốt nền',
                        currentOpacity: fillOpacity,
                        onTap: () => _showOpacityPickerDialog(context),
                      ),
                    ],
                  ),
                ),

                // Ghi chú nhỏ cho người dùng ở cuối danh sách
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Các thay đổi sẽ được áp dụng trực tiếp lên màn hình nhận diện.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng thanh tiêu đề cho Drawer với nút đóng (X)
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Display options',
            style: TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Phân đoạn tiêu đề nhóm (Section Header)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Mục cài đặt dạng Bật/Tắt sử dụng [CupertinoSwitch] để có giao diện mượt mà
  Widget _buildToggleItem({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: CupertinoColors.activeGreen,
        onChanged: onChanged,
      ),
    );
  }

  /// Mục hiển thị giá trị độ trong suốt hiện tại và cho phép nhấn để chọn lại
  Widget _buildOpacityPickerItem({
    required String label,
    required double currentOpacity,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.opacity, color: Colors.blueAccent, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(currentOpacity * 100).toInt()}%',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  /// Mục hiển thị màu sắc hiện tại dưới dạng một vòng tròn nhỏ (Color Indicator)
  Widget _buildColorPickerItem({required String label, required Color currentColor, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.palette, color: Colors.blueAccent, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12, width: 1),
        ),
      ),
    );
  }

  /// Mở một menu dạng [CupertinoActionSheet] để người dùng chọn từ danh sách màu định sẵn
  void _showColorPickerDialog(BuildContext context) {
    const List<Map<String, dynamic>> colorOptions = [
      {'name': 'Đỏ', 'color': Colors.red},
      {'name': 'Xanh lá', 'color': Colors.green},
      {'name': 'Xanh dương', 'color': Colors.blue},
      {'name': 'Xanh accent', 'color': Colors.cyanAccent},
      {'name': 'Tím', 'color': Colors.purple},
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Chọn màu sắc khung'),
        actions: colorOptions.map((opt) => CupertinoActionSheetAction(
          onPressed: () {
            onOptionChanged('color', opt['color']);
            Navigator.pop(context);
          },
          child: Text(opt['name'], style: TextStyle(color: opt['color'])),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  /// Mở menu để chọn các mức độ trong suốt (Opacity)
  void _showOpacityPickerDialog(BuildContext context) {
    const List<Map<String, dynamic>> opacityOptions = [
      {'label': 'Trong suốt (0%)', 'value': 0.0},
      {'label': 'Mờ nhẹ (25%)', 'value': 0.25},
      {'label': 'Mờ vừa (50%)', 'value': 0.5},
      {'label': 'Mờ cao (75%)', 'value': 0.75},
      {'label': 'Màu đặc (100%)', 'value': 1.0},
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Độ trong suốt màu nền'),
        actions: opacityOptions.map((opt) => CupertinoActionSheetAction(
          onPressed: () {
            onOptionChanged('opacity', opt['value']);
            Navigator.pop(context);
          },
          child: Text(opt['label']),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  /// Tạo đường kẻ phân cách ngắn (không kéo dài hết sang lề trái), giống style iOS Settings
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56, // Thừa ra một khoảng để thẳng hàng với text (sau icon)
      color: Color(0xFFE5E5EA),
    );
  }
}