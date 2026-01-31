import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../services/detection_processor.dart';
import '../widgets/menu_mode_selector.dart';
import '../widgets/menu_display_options.dart';
import '../services/counting_service.dart';
import '../services/preferences_service.dart';
import '../models/detection_result.dart';
import '../helpers/ui_helpers.dart';
import './bounding_box_painter.dart';

/// [CountingScreen] là lớp quản lý giao diện và logic chính của tính năng đếm đối tượng.
/// Màn hình này chịu trách nhiệm hiển thị ảnh, điều phối quá trình suy luận AI (Inference)
/// và hiển thị các lớp phủ đồ họa (Bounding Boxes) dựa trên kết quả trả về.
class CountingScreen extends StatefulWidget {
  final String imagePath; // Đường dẫn vật lý của tệp ảnh được chọn.

  const CountingScreen({super.key, required this.imagePath});

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  // --- CORE CONTROLLERS ---
  // Chụp ảnh màn hình bao gồm cả phần vẽ CustomPaint.
  final ScreenshotController _screenshotController = ScreenshotController();
  // Xử lý logic tải model và gọi hàm đếm.
  final CountingService _countingService = CountingService();
  // Quản lý lưu trữ cục bộ các tùy chọn người dùng.
  final PreferencesService _prefsService = PreferencesService();

  // --- UI DISPLAY STATE (Các biến điều khiển trạng thái hiển thị) ---
  bool _showBoundingBoxes = true;
  bool _showConfidence = true;
  bool _showFillBox = false;
  bool _showOrderNumber = false;
  bool _isMultiColor = true;
  double _fillOpacity = 0.4;
  Color _boxColor = Colors.amber;

  // --- DATA & PROCESSING STATE ---
  List<DetectionResult> _detectionResults = []; // Chứa danh sách đối tượng AI tìm được.
  bool _isCounting = false; // Trạng thái xử lý để hiển thị Loading UI và chặn tương tác thừa.
  ui.Image? _originalImage; // Lưu trữ cấu trúc ảnh gốc để tính toán tỷ lệ khung hình (Aspect Ratio).
  SelectedMode? _selectedMode; // Chế độ đếm hiện tại (định nghĩa class mục tiêu cho AI).

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Khởi tạo các cấu hình hiển thị đã lưu.
    _loadImage();       // Giải mã ảnh ngay khi vào màn hình.
  }

  @override
  void dispose() {
    // [QUAN TRỌNG]: Giải phóng bộ nhớ RAM từ các đối tượng đồ họa cấp thấp và Model AI.
    _originalImage?.dispose();
    _countingService.dispose();
    super.dispose();
  }

  /// Tải cấu hình hiển thị từ bộ nhớ cục bộ (SharedPreferences).
  Future<void> _loadPreferences() async {
    final loadedMode = await _prefsService.loadSelectedMode();
    final displayPrefs = await _prefsService.loadDisplayPreferences();
    if (mounted) {
      setState(() {
        _selectedMode = loadedMode;
        _showBoundingBoxes = displayPrefs.showBoundingBoxes;
        _showConfidence = displayPrefs.showConfidence;
        _showFillBox = displayPrefs.showFillBox;
        _showOrderNumber = displayPrefs.showOrderNumber;
        _isMultiColor = displayPrefs.showMultiColor;
        _fillOpacity = displayPrefs.opacity;
        _boxColor = displayPrefs.boxColor;
      });
    }
  }

  /// Giải mã tệp ảnh thành đối tượng [ui.Image] để lấy kích thước điểm ảnh (pixel) chính xác.
  Future<void> _loadImage() async {
    final data = await File(widget.imagePath).readAsBytes();
    final image = await decodeImageFromList(data);
    if (mounted) setState(() => _originalImage = image);
  }

  /// [HÀM XỬ LÝ TRÊN ISOLATE]: Đây là hàm tĩnh chạy trên một luồng CPU riêng biệt.
  /// Việc đưa logic xử lý mô hình AI vào đây giúp Main Thread (Giao diện) không bị giật lag
  /// khi CPU thực hiện các phép toán nặng của mô hình TFLite.
  static Future<void> _runInferenceIsolate(Map<String, dynamic> params) async {
    final SendPort sendPort = params['sendPort']; // Cổng gửi dữ liệu về Main Isolate.

    try {
      final String imagePath = params['imagePath'];
      final Uint8List modelBytes = params['modelBytes'];
      final int targetClass = params['targetClass'];
      final List<String> labels = List<String>.from(params['labels']);

      final isolateService = CountingService();

      try {
        // Tải model và thực hiện suy luận trong môi trường Isolate.
        await isolateService.loadModelFromBytes(modelBytes, labels);
        final results = await isolateService.countObjects(imagePath, targetClass: targetClass);

        // Gửi kết quả về cho UI.
        sendPort.send(results);
      } finally {
        isolateService.dispose();
      }
    } catch (e) {
      sendPort.send(<DetectionResult>[]); // Gửi danh sách rỗng nếu có lỗi xảy ra.
    }
  }

  /// Khởi động quy trình đếm đối tượng.
  Future<void> _startCounting() async {
    if (_isCounting || _selectedMode == null) return;

    setState(() {
      _isCounting = true;
      _detectionResults = [];
    });

    UIHelper.showLoadingIndicator(context, message: 'processing...');

    try {
      // 1. Chuẩn bị dữ liệu Model từ Assets (Dữ liệu lớn cần được load dưới dạng Bytes).
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      final List<String> labelsList = labelsData.split('\n').map((l) =>
          l.trim()).where((l) => l.isNotEmpty).toList();
      final modelData = await rootBundle.load(
          'assets/yolo11m_obb_bullet_couter_preview_float16.tflite');
      final Uint8List modelBytes = modelData.buffer.asUint8List();

      // 2. Thiết lập kênh giao tiếp giữa các luồng.
      final receivePort = ReceivePort();

      // 3. Spawn Isolate mới để chạy AI tách biệt với UI.
      await Isolate.spawn(
        _runInferenceIsolate,
        {
          'sendPort': receivePort.sendPort,
          'imagePath': widget.imagePath,
          'modelBytes': modelBytes,
          'targetClass': _selectedMode!.targetClass,
          'labels': labelsList,
        },
      );

      // 4. Nhận kết quả đầu tiên trả về và đóng cổng.
      final results = await receivePort.first as List<DetectionResult>;

      if (mounted) {
        setState(() => _detectionResults = results);
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi xử lý AI: $e');
    } finally {
      if (mounted) {
        UIHelper.hideLoadingIndicator(context);
        setState(() => _isCounting = false);
      }
    }
  }

  /// Chụp lại màn hình hiện tại (bao gồm ảnh gốc và các Bounding Box đã vẽ) để lưu vào máy.
  Future<void> _saveImageToGallery() async {
    if (!mounted || _isCounting) return;

    UIHelper.showLoadingIndicator(context, message: 'Đang chuẩn bị ảnh...');
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Chụp widget nằm trong Screenshot controller.
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0, // Tăng độ nét ảnh chụp lên gấp đôi.
      );

      if (imageBytes != null) {
        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: "Result_${DateTime.now().millisecondsSinceEpoch}",
        );
        if (mounted && result['isSuccess'] == true) {
          UIHelper.showSuccessSnackBar(context, 'Đã lưu ảnh thành công!');
        }
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi lưu ảnh: $e');
    } finally {
      if (mounted) UIHelper.hideLoadingIndicator(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = _detectionResults.length;

    return PopScope(
      canPop: false, // Ngăn chặn thoát màn hình vô ý khi đang xử lý.
      child: Screenshot(
        controller: _screenshotController,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(totalCount),
          endDrawer: _buildDrawer(),
          body: _buildImageBody(),
          bottomNavigationBar: _buildBottomBar(),
        ),
      ),
    );
  }

  // --- UI COMPONENTS (Tách nhỏ để dễ quản lý) ---

  /// AppBar hiển thị số lượng đếm được và chế độ hiện tại.
  PreferredSize _buildAppBar(int totalCount) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70.0),
      child: AppBar(
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(text: 'Target: ',
                        style: TextStyle(fontFamily: 'Lexend',
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    TextSpan(text: '$totalCount',
                        style: const TextStyle(fontFamily: 'Lexend',
                            color: Colors.orangeAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text('- Mode: ${_selectedMode?.name ?? 'Chưa chọn'} -',
                  style: const TextStyle(
                      color: Colors.deepOrange, fontSize: 14)),
            ]
        ),
        actions: [
          Builder(builder: (context) =>
              IconButton(icon: const Icon(Icons.tune),
                  onPressed: () => Scaffold.of(context).openEndDrawer())),
        ],
      ),
    );
  }

  /// Phần thân hiển thị ảnh và tính toán tỷ lệ khung hình hiển thị (Display Size vs Original Size).
  Widget _buildImageBody() {
    if (_originalImage == null) return const Center(child: CircularProgressIndicator(color: Colors.amber));

    return LayoutBuilder(
      builder: (context, constraints) {
        // TÍNH TOÁN TỶ LỆ: Đảm bảo ảnh hiển thị đúng tỷ lệ gốc trong mọi kích thước màn hình.
        double imgW = _originalImage!.width.toDouble();
        double imgH = _originalImage!.height.toDouble();
        double ratio = imgW / imgH;

        double displayWidth = constraints.maxWidth;
        double displayHeight = constraints.maxWidth / ratio;

        if (displayHeight > constraints.maxHeight) {
          displayHeight = constraints.maxHeight;
          displayWidth = displayHeight * ratio;
        }

        return InteractiveViewer( // Cho phép người dùng Zoom và Pan ảnh.
          clipBehavior: Clip.none,
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                children: [
                  Positioned.fill(child: Image.file(File(widget.imagePath), fit: BoxFit.fill)),

                  // LỚP VẼ ĐỒ HỌA: Chuyển đổi tọa độ AI sang tọa độ màn hình.
                  if (_detectionResults.isNotEmpty)
                    Positioned.fill(
                      child: Builder(
                        builder: (context) {
                          // Processor giúp tính toán tọa độ (Scaling) trước khi truyền vào Painter.
                          final processedData = DetectionProcessor.process(
                            results: _detectionResults,
                            originalSize: Size(imgW, imgH),
                            screenSize: Size(displayWidth, displayHeight),
                            baseBoxColor: _boxColor,
                            isMultiColor: _isMultiColor,
                          );

                          return CustomPaint(
                            painter: BoundingBoxPainter(
                              processedResults: processedData,
                              showBoundingBoxes: _showBoundingBoxes,
                              showConfidence: _showConfidence,
                              showFillBox: _showFillBox,
                              showOrderNumber: _showOrderNumber,
                              fillOpacity: _fillOpacity,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Drawer hiển thị các tùy chọn cấu hình.
  Widget _buildDrawer() {
    return DisplayOptionsDrawer(
      showBoundingBoxes: _showBoundingBoxes,
      showConfidence: _showConfidence,
      showFillBox: _showFillBox,
      showOrderNumber: _showOrderNumber,
      isMultiColor: _isMultiColor,
      fillOpacity: _fillOpacity,
      boxColor: _boxColor,
      onOptionChanged: (key, newValue) {
        setState(() {
          if (key == 'box') _showBoundingBoxes = newValue;
          if (key == 'fill') _showFillBox = newValue;
          if (key == 'order') _showOrderNumber = newValue;
          if (key == 'confidence') _showConfidence = newValue;
          if (key == 'multiColor') _isMultiColor = newValue;
          if (key == 'opacity') _fillOpacity = newValue;
          if (key == 'color') _boxColor = newValue;
        });
        _prefsService.saveDisplayPreferences(
          DisplayPreferences(
            showBoundingBoxes: _showBoundingBoxes,
            showConfidence: _showConfidence,
            showFillBox: _showFillBox,
            showOrderNumber: _showOrderNumber,
            showMultiColor: _isMultiColor,
            opacity: _fillOpacity,
            boxColor: _boxColor,
          ),
        );
      },
    );
  }

  /// Thanh điều khiển dưới cùng với nút đếm chính.
  Widget _buildBottomBar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: ElevatedButton(
              onPressed: (_isCounting || _selectedMode == null) ? null : _startCounting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('COUNT', style: TextStyle(color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lexend')),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 45),
                onPressed: _isCounting ? null : _saveImageToGallery,
              ),
              ModeSelector(
                currentModeName: _selectedMode?.name ?? 'Chọn Mode',
                currentModeImage: _selectedMode?.image,
                onModeSelected: (id, name, img) {
                  final newMode = SelectedMode(targetClass: id, name: name, image: img);
                  _prefsService.saveSelectedMode(newMode);
                  setState(() {
                    _selectedMode = newMode;
                    _detectionResults = []; // Reset kết quả khi đổi chế độ.
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}