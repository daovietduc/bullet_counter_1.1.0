import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

// --- CẤU TRÚC MODULES ---
import '../widgets/counting_image_display.dart';
import '../widgets/counting_bottom_bar.dart';
import '../widgets/menu_display_options.dart';
import '../widgets/scan_effect.dart';
import '../services/counting_service.dart';
import '../services/preferences_service.dart';
import '../models/detection_result.dart';
import '../helpers/ui_helpers.dart';

/// [CountingScreen] chịu trách nhiệm xử lý hậu kỳ cho hình ảnh đã chụp.
/// Quy trình hoạt động chính:
/// 1. Tải ảnh từ đường dẫn bộ nhớ tạm.
/// 2. Khởi tạo mô hình AI (YOLO) trong một luồng riêng ([Isolate]).
/// 3. Hiển thị lớp phủ đồ họa (Overlay) dựa trên tọa độ vật thể phát hiện được.
/// 4. Cho phép người dùng tùy chỉnh hiển thị và lưu kết quả cuối cùng.
class CountingScreen extends StatefulWidget {
  /// Đường dẫn vật lý của file ảnh vừa chụp hoặc chọn từ thư viện.
  final String imagePath;

  const CountingScreen({super.key, required this.imagePath});

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  // --- BỘ ĐIỀU KHIỂN & DỊCH VỤ (CONTROLLERS & SERVICES) ---

  /// Chụp ảnh màn hình vùng làm việc để xuất file kết quả bao gồm cả các khung nhận diện.
  final ScreenshotController _screenshotController = ScreenshotController();

  /// Logic nghiệp vụ chính để giao tiếp với mô hình TensorFlow Lite.
  final CountingService _countingService = CountingService();

  /// Quản lý việc lưu/tải các tùy chọn hiển thị (Show/Hide boxes, colors) vào bộ nhớ máy.
  final PreferencesService _prefsService = PreferencesService();

  // --- CẤU HÌNH HIỂN THỊ (DISPLAY CONFIGURATION) ---
  bool _showBoundingBoxes = true;
  bool _showConfidence = true;
  bool _showFillBox = false;
  bool _showOrderNumber = false;
  bool _isMultiColor = true;
  double _fillOpacity = 0.4;
  Color _boxColor = Colors.amber;

  // --- QUẢN LÝ DỮ LIỆU & TRẠNG THÁI (DATA MANAGEMENT) ---

  /// Danh sách các đối tượng đã được AI nhận diện thành công.
  List<DetectionResult> _detectionResults = [];

  /// Cờ kiểm soát trạng thái xử lý để tránh người dùng kích hoạt nhiều tiến trình AI cùng lúc.
  bool _isCounting = false;

  /// Đối tượng ảnh cấp thấp dùng để vẽ lên [CustomPainter] với độ chính xác cao.
  ui.Image? _originalImage;

  /// Chế độ nhận diện đang được chọn (Ví dụ: Đếm đạn, đếm gạch, đếm linh kiện...).
  SelectedMode? _selectedMode;

  @override
  void initState() {
    super.initState();
    // Khởi tạo song song: Tải cài đặt người dùng và chuẩn bị dữ liệu hình ảnh.
    _loadPreferences();
    _loadImage();
  }

  @override
  void dispose() {
    // Giải phóng bộ nhớ RAM từ các đối tượng nặng (Ảnh, Isolate, Controller).
    _originalImage?.dispose();
    _countingService.dispose();
    super.dispose();
  }

  // --- LOGIC KHỞI TẠO (INITIALIZATION LOGIC) ---

  /// Khôi phục các thiết lập hiển thị từ lần sử dụng trước đó.
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

  /// Giải mã file vật lý thành [ui.Image].
  /// Bước này cần thiết để [CustomPainter] có thể render ảnh với tỷ lệ chuẩn xác.
  Future<void> _loadImage() async {
    try {
      final data = await File(widget.imagePath).readAsBytes();
      final image = await decodeImageFromList(data);
      if (mounted) setState(() => _originalImage = image);
    } catch (e) {
      debugPrint("Lỗi giải mã hình ảnh: $e");
    }
  }

  // --- XỬ LÝ ĐA LUỒNG (PARALLEL PROCESSING) ---

  /// [Isolate] Function: Chạy tiến trình AI tách biệt hoàn toàn khỏi luồng chính (Main UI Isolate).
  /// @param params: Map chứa các tài nguyên cần thiết để khởi chạy AI.
  /// Giải thích: Việc chạy AI cực kỳ tốn CPU. Nếu chạy trực tiếp trên luồng chính,
  /// ứng dụng sẽ bị "đóng băng" (Jank) khiến các hiệu ứng Scan không thể hoạt động.
  static Future<void> _runInferenceIsolate(Map<String, dynamic> params) async {
    final SendPort sendPort = params['sendPort'];
    final isolateService = CountingService();
    try {
      await isolateService.loadModelFromBytes(params['modelBytes'], params['labels']);
      final results = await isolateService.countObjects(
          params['imagePath'],
          targetClass: params['targetClass']
      );
      sendPort.send(results);
    } catch (e) {
      sendPort.send(<DetectionResult>[]);
    } finally {
      isolateService.dispose();
    }
  }

  /// Kích hoạt quy trình đếm đối tượng.
  Future<void> _startCounting() async {
    if (_isCounting || _selectedMode == null) return;

    setState(() {
      _isCounting = true;
      _detectionResults = []; // Xóa kết quả cũ để chuẩn bị đếm mới
    });

    UIHelper.showLoadingIndicator(context, message: 'AI đang phân tích...');

    try {
      // 1. Chuẩn bị tài nguyên AI từ thư mục assets.
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      final labelsList = labelsData.split('\n').map((l) => l.trim()).toList();
      final modelData = await rootBundle.load('assets/yolo11m_obb_bullet_couter_preview_float16.tflite');
      final modelBytes = modelData.buffer.asUint8List();

      // 2. Khởi tạo Port để nhận dữ liệu từ luồng Isolate quay về luồng Main.
      final receivePort = ReceivePort();
      await Isolate.spawn(_runInferenceIsolate, {
        'sendPort': receivePort.sendPort,
        'imagePath': widget.imagePath,
        'modelBytes': modelBytes,
        'targetClass': _selectedMode!.targetClass,
        'labels': labelsList,
      });

      // 3. Chờ đợi kết quả và cập nhật trạng thái UI.
      final results = await receivePort.first as List<DetectionResult>;
      if (mounted) {
        setState(() => _detectionResults = results);
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi AI: $e');
    } finally {
      if (mounted) {
        UIHelper.hideLoadingIndicator(context);
        setState(() => _isCounting = false);
      }
    }
  }

  // --- CÁC HÀNH ĐỘNG NGƯỜI DÙNG (USER ACTIONS) ---

  /// Chụp lại màn hình vùng làm việc và ghi vào thư viện ảnh của máy.
  Future<void> _saveImageToGallery() async {
    if (!mounted || _isCounting) return;

    UIHelper.showLoadingIndicator(context, message: 'Đang kết xuất hình ảnh...');
    try {
      // Capture với pixelRatio cao (2.0) giúp ảnh lưu lại sắc nét hơn ảnh hiển thị trên màn hình.
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      if (imageBytes != null) {
        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: "Result_${DateTime.now().millisecondsSinceEpoch}",
        );
        if (mounted && result['isSuccess'] == true) {
          UIHelper.showSuccessSnackBar(context, 'Lưu thành công!');
        }
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi lưu trữ: $e');
    } finally {
      if (mounted) UIHelper.hideLoadingIndicator(context);
    }
  }

  // --- XÂY DỰNG GIAO DIỆN (UI RENDERING) ---

  /// Header chứa thông tin tổng kết: Số lượng đã đếm và Chế độ hiện tại.
  PreferredSize _buildAppBar() {
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
                  const TextSpan(text: 'Target: ', style: TextStyle(fontFamily: 'Lexend', color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  TextSpan(text: '${_detectionResults.length}', style: const TextStyle(fontFamily: 'Lexend', color: Colors.orangeAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text('- Mode: ${_selectedMode?.name ?? '...'} -', style: const TextStyle(color: Colors.deepOrange, fontSize: 14)),
          ],
        ),
        actions: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Chặn thoát bằng cử chỉ vuốt để đảm bảo người dùng không vô tình mất kết quả.
      child: Screenshot(
        controller: _screenshotController,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(),

          /// Drawer (Menu bên phải) dùng để tùy chỉnh trải nghiệm thị giác.
          endDrawer: DisplayOptions(
            showBoundingBoxes: _showBoundingBoxes,
            showConfidence: _showConfidence,
            showFillBox: _showFillBox,
            showOrderNumber: _showOrderNumber,
            isMultiColor: _isMultiColor,
            fillOpacity: _fillOpacity,
            boxColor: _boxColor,
            onOptionChanged: (key, newValue) {
              setState(() {
                // Ánh xạ các thay đổi từ menu vào State của Screen.
                if (key == 'box') _showBoundingBoxes = newValue;
                if (key == 'fill') _showFillBox = newValue;
                if (key == 'order') _showOrderNumber = newValue;
                if (key == 'confidence') _showConfidence = newValue;
                if (key == 'multiColor') _isMultiColor = newValue;
                if (key == 'opacity') _fillOpacity = newValue;
                if (key == 'color') _boxColor = newValue;
              });

              // Đồng bộ hóa tức thì vào bộ nhớ lưu trữ.
              _prefsService.saveDisplayPreferences(DisplayPreferences(
                showBoundingBoxes: _showBoundingBoxes,
                showConfidence: _showConfidence,
                showFillBox: _showFillBox,
                showOrderNumber: _showOrderNumber,
                showMultiColor: _isMultiColor,
                opacity: _fillOpacity,
                boxColor: _boxColor,
              ));
            },
          ),

          body: Stack(
            children: [
              Center(
                child: AspectRatio(
                  // Đảm bảo khung hiển thị luôn khớp chính xác với tỷ lệ ảnh gốc.
                  aspectRatio: _originalImage != null
                      ? _originalImage!.width / _originalImage!.height
                      : 1.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      /// Lớp hiển thị ảnh và vẽ tọa độ (Detection Overlays).
                      ImageDisplay(
                        originalImage: _originalImage,
                        imagePath: widget.imagePath,
                        detectionResults: _detectionResults,
                        showBoundingBoxes: _showBoundingBoxes,
                        showConfidence: _showConfidence,
                        showFillBox: _showFillBox,
                        showOrderNumber: _showOrderNumber,
                        isMultiColor: _isMultiColor,
                        fillOpacity: _fillOpacity,
                        boxColor: _boxColor,
                      ),

                      /// Hiệu ứng thẩm mỹ: Tia quét laser chạy dọc khi đang xử lý AI.
                      if (_isCounting)
                        Positioned.fill(
                          child: ScanEffect(
                            scanColor: Colors.cyanAccent,
                            duration: const Duration(seconds: 2),
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          /// Footer điều hướng: Chứa logic chọn Model và lệnh thực thi Chụp/Lưu.
          bottomNavigationBar: CountingBottomBar(
            isCounting: _isCounting,
            currentModeName: _selectedMode?.name ?? 'Chọn Mode',
            currentModeImage: _selectedMode?.image,
            onCountPressed: _startCounting,
            onSavePressed: _saveImageToGallery,
            onModeSelected: (id, name, img) {
              final newMode = SelectedMode(
                targetClass: id,
                name: name,
                image: img ?? '',
              );

              _prefsService.saveSelectedMode(newMode);
              setState(() {
                _selectedMode = newMode;
                _detectionResults = []; // Reset để đảm bảo dữ liệu đếm khớp với Model mới.
              });
            },
          ),
        ),
      ),
    );
  }
}