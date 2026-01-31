import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

// Import các thành phần giao diện (Widgets)
import '../widgets/counting_image_display.dart';
import '../widgets/counting_bottom_bar.dart';
import '../widgets/menu_display_options.dart';

// Import các dịch vụ xử lý logic (Services)
import '../services/counting_service.dart';
import '../services/preferences_service.dart';
import '../models/detection_result.dart';
import '../helpers/ui_helpers.dart';

/// [CountingScreen] là màn hình chính thực hiện chức năng nhận diện và đếm đối tượng.
/// Màn hình này nhận vào một [imagePath] để hiển thị và xử lý AI.
class CountingScreen extends StatefulWidget {
  final String imagePath;

  const CountingScreen({super.key, required this.imagePath});

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  // --- BỘ ĐIỀU KHIỂN (CONTROLLERS) ---

  /// Chụp màn hình vùng widget để lưu kết quả
  final ScreenshotController _screenshotController = ScreenshotController();

  /// Dịch vụ xử lý nhận diện AI (YOLO)
  final CountingService _countingService = CountingService();

  /// Dịch vụ lưu trữ cấu hình người dùng (SharedPreferences)
  final PreferencesService _prefsService = PreferencesService();

  // --- TRẠNG THÁI: TÙY CHỌN HIỂN THỊ (DISPLAY OPTIONS) ---
  bool _showBoundingBoxes = true; // Hiển thị khung bao
  bool _showConfidence = true;    // Hiển thị độ tin cậy (%)
  bool _showFillBox = false;      // Tô màu nền khung bao
  bool _showOrderNumber = false;  // Hiển thị số thứ tự đếm
  bool _isMultiColor = true;      // Sử dụng nhiều màu cho các đối tượng
  double _fillOpacity = 0.4;      // Độ trong suốt của màu nền
  Color _boxColor = Colors.amber; // Màu sắc mặc định của khung

  // --- TRẠNG THÁI: DỮ LIỆU (DATA STATE) ---
  List<DetectionResult> _detectionResults = []; // Danh sách kết quả từ AI
  bool _isCounting = false;                     // Trạng thái đang xử lý
  ui.Image? _originalImage;                     // Đối tượng ảnh gốc để vẽ Canvas
  SelectedMode? _selectedMode;                  // Chế độ đếm hiện tại (vd: đếm đạn, đếm gạch...)

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Tải cấu hình đã lưu trước đó
    _loadImage();       // Giải mã file ảnh thành object ui.Image
  }

  @override
  void dispose() {
    _originalImage?.dispose();
    _countingService.dispose();
    super.dispose();
  }

  // --- LOGIC: KHỞI TẠO (INITIALIZATION) ---

  /// Tải các cài đặt người dùng từ bộ nhớ máy
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

  /// Chuyển đổi file ảnh từ đường dẫn thành định dạng [ui.Image] để xử lý đồ họa
  Future<void> _loadImage() async {
    try {
      final data = await File(widget.imagePath).readAsBytes();
      final image = await decodeImageFromList(data);
      if (mounted) setState(() => _originalImage = image);
    } catch (e) {
      debugPrint("Lỗi tải ảnh: $e");
    }
  }

  // --- LOGIC: XỬ LÝ AI (ISOLATE) ---

  /// Hàm chạy độc lập (Isolate) để thực hiện AI inference mà không gây lag UI.
  /// [params] chứa SendPort, byte model, nhãn và đường dẫn ảnh.
  static Future<void> _runInferenceIsolate(Map<String, dynamic> params) async {
    final SendPort sendPort = params['sendPort'];
    final isolateService = CountingService();
    try {
      // Tải model vào bộ nhớ của Isolate
      await isolateService.loadModelFromBytes(params['modelBytes'], params['labels']);
      // Chạy nhận diện
      final results = await isolateService.countObjects(
          params['imagePath'],
          targetClass: params['targetClass']
      );
      sendPort.send(results); // Gửi kết quả về main isolate
    } catch (e) {
      sendPort.send(<DetectionResult>[]); // Gửi danh sách rỗng nếu lỗi
    } finally {
      isolateService.dispose();
    }
  }

  /// Kích hoạt quá trình đếm đối tượng sử dụng mô hình AI
  Future<void> _startCounting() async {
    if (_isCounting || _selectedMode == null) return;

    setState(() {
      _isCounting = true;
      _detectionResults = [];
    });

    UIHelper.showLoadingIndicator(context, message: 'processing...');

    try {
      // 1. Tải tài nguyên (labels và model)
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      final labelsList = labelsData.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final modelData = await rootBundle.load('assets/yolo11m_obb_bullet_couter_preview_float16.tflite');
      final modelBytes = modelData.buffer.asUint8List();

      // 2. Thiết lập Isolate để tránh đứng hình (UI jank)
      final receivePort = ReceivePort();
      await Isolate.spawn(_runInferenceIsolate, {
        'sendPort': receivePort.sendPort,
        'imagePath': widget.imagePath,
        'modelBytes': modelBytes,
        'targetClass': _selectedMode!.targetClass,
        'labels': labelsList,
      });

      // 3. Nhận kết quả và cập nhật giao diện
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

  // --- LOGIC: HÀNH ĐỘNG (ACTIONS) ---

  /// Chụp ảnh màn hình kết quả và lưu vào thư viện ảnh của thiết bị
  Future<void> _saveImageToGallery() async {
    if (!mounted || _isCounting) return;

    UIHelper.showLoadingIndicator(context, message: 'Đang chuẩn bị ảnh...');
    try {
      // Chụp widget nằm trong Screenshot controller
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0, // Tăng chất lượng ảnh lưu
      );

      if (imageBytes != null) {
        final result = await ImageGallerySaverPlus.saveImage(
          imageBytes,
          quality: 100,
          name: "Result_${DateTime.now().millisecondsSinceEpoch}",
        );
        if (mounted && result['isSuccess'] == true) {
          UIHelper.showSuccessSnackBar(context, 'Đã lưu ảnh vào thư viện!');
        }
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Lỗi lưu ảnh: $e');
    } finally {
      if (mounted) UIHelper.hideLoadingIndicator(context);
    }
  }

  // --- THÀNH PHẦN GIAO DIỆN (UI COMPONENTS) ---

  /// Thanh AppBar tùy chỉnh hiển thị số lượng vật thể đếm được
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
                  const TextSpan(text: 'Target: ',
                      style: TextStyle(fontFamily: 'Lexend',
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  TextSpan(text: '${_detectionResults.length}',
                      style: const TextStyle(fontFamily: 'Lexend',
                          color: Colors.orangeAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text('- Mode: ${_selectedMode?.name ?? 'Chưa chọn'} -',
                style: const TextStyle(color: Colors.deepOrange, fontSize: 14)),
          ],
        ),
        actions: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.tune, color: Colors.white), // Nút mở cài đặt hiển thị
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Ngăn chặn thoát bằng nút back hệ thống để kiểm soát trạng thái
      child: Screenshot(
        controller: _screenshotController,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(),
          // Drawer bên phải chứa các tùy chỉnh hiển thị
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
                if (key == 'box') _showBoundingBoxes = newValue;
                if (key == 'fill') _showFillBox = newValue;
                if (key == 'order') _showOrderNumber = newValue;
                if (key == 'confidence') _showConfidence = newValue;
                if (key == 'multiColor') _isMultiColor = newValue;
                if (key == 'opacity') _fillOpacity = newValue;
                if (key == 'color') _boxColor = newValue;
              });
              // Lưu cấu hình ngay khi người dùng thay đổi
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
          // Thành phần chính hiển thị ảnh và các khung nhận diện
          body: ImageDisplay(
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
          // Thanh điều khiển phía dưới: Chọn mode, Nút Đếm, Nút Lưu
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
                image: img ?? '', // Xử lý null-safety
              );

              _prefsService.saveSelectedMode(newMode);
              setState(() {
                _selectedMode = newMode;
                _detectionResults = []; // Reset kết quả cũ để người dùng đếm lại theo mode mới
              });
            },
          ),
        ),
      ),
    );
  }
}