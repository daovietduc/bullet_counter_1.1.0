import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Một widget Drawer để hiển thị các tùy chọn cài đặt giao diện.
/// Cho phép người dùng bật/tắt các yếu tố như bounding box, độ tin cậy,
/// cũng như tùy chỉnh màu sắc và độ trong suốt của chúng.
class DisplayOptionsDrawer extends StatelessWidget {
  // Trạng thái của các tùy chọn hiển thị
  final bool showBoundingBoxes;
  final bool showConfidence;
  final bool showFillBox;
  final bool showOrderNumber;
  final bool isMultiColor;
  final double fillOpacity;
  final Color boxColor;

  /// Callback được gọi khi một tùy chọn thay đổi.
  final Function(String key, dynamic value) onOptionChanged;

  const DisplayOptionsDrawer({
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
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: const Color(0xFFF2F2F7), // Màu nền xám nhạt (kiểu iOS)
      child: Column(
        children: [
          _buildHeader(context),
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

  /// Xây dựng phần header cho drawer.
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

  /// Xây dựng tiêu đề cho một nhóm cài đặt.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Xây dựng một mục cài đặt có công tắc (toggle switch).
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

  /// Xây dựng một mục để chọn độ trong suốt.
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

  /// Xây dựng một mục để chọn màu sắc.
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

  /// Hiển thị hộp thoại (Action Sheet) để chọn màu.
  void _showColorPickerDialog(BuildContext context) {
    // Danh sách các màu có sẵn để chọn
    // Chuyển thành static const để không phải tạo lại mỗi lần hàm được gọi
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

  /// Hiển thị hộp thoại (Action Sheet) để chọn độ trong suốt.
  void _showOpacityPickerDialog(BuildContext context) {
    // Danh sách các mức độ trong suốt có sẵn
    // Chuyển thành static const để không phải tạo lại mỗi lần hàm được gọi
    const List<Map<String, dynamic>> opacityOptions = [
      {'label': 'Trong suốt (0%)', 'value': 0},
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

  /// Xây dựng một đường kẻ phân cách.
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56, // Căn lề trái để thẳng hàng với tiêu đề của ListTile
      color: Color(0xFFE5E5EA),
    );
  }
}
