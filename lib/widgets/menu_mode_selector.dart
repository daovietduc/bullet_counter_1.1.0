import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  final Function(int classId, String modeName, String modeImage) onModeSelected;
  final String currentModeName;
  final String? currentModeImage;

  const ModeSelector({
    super.key,
    required this.onModeSelected,
    required this.currentModeName,
    this.currentModeImage,
  });

  void _showModeSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ModeSelectorSheetContent(
          onModeSelected: onModeSelected,
          currentModeName: currentModeName,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showModeSelectionSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          // Cập nhật: Sử dụng withValues thay cho withOpacity
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildImageWidget(currentModeImage),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.broken_image, color: Colors.white, size: 24),
      );
    } else {
      return const Icon(Icons.category, color: Colors.white, size: 24);
    }
  }
}

class _ModeSelectorSheetContent extends StatelessWidget {
  final Function(int classId, String modeName, String modeImage) onModeSelected;
  final String currentModeName;

  const _ModeSelectorSheetContent({
    required this.onModeSelected,
    required this.currentModeName,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modes = [
      {"name": "K51", "image": "assets/images/K51.png", "classID": 0},
      {"name": "K59", "image": "assets/images/K59.png", "classID": 1},
      {"name": "K56", "image": "assets/images/K56.png", "classID": 2},
      {"name": "K53", "image": "assets/images/K53.png", "classID": 3},
      {"name": "12,7mm", "image": "assets/images/12,7.png", "classID": 4},
      {"name": "14,5mm", "image": "assets/images/14,5.png", "classID": 5},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Khoảng cách trên cùng
          const SizedBox(height: 12),
          Container(
            height: 5,
            width: 45,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // 2. Khoảng cách giữa handle và tiêu đề
          const SizedBox(height: 16),
          const Text(
            "Select Bullet Type",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          // 3. Khoảng cách giữa tiêu đề và lưới
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 30),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.85,
            ),
            itemCount: modes.length,
            itemBuilder: (context, index) {
              final mode = modes[index];
              final bool isSelected = currentModeName == mode["name"];

              return InkWell(
                onTap: () {
                  onModeSelected(mode["classID"], mode["name"], mode["image"]);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        // Cập nhật: withValues cho shadow
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              mode["image"],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Khoảng cách giữa ảnh và text
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                        child: Text(
                          mode["name"],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.blueAccent : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}