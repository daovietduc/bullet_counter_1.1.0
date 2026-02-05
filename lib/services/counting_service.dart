import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img; // Thư viện xử lý pixel: dùng để resize và chuẩn hóa ảnh
import 'package:tflite_flutter/tflite_flutter.dart'; // Thư viện cầu nối chạy AI TensorFlow Lite
import '../models/detection_result.dart'; // Model chứa kết quả: đỉnh xoay, độ tự tin, class...

/// ============================================================================
/// SERVICE XỬ LÝ ĐẾM VẬT THỂ VỚI YOLOV11-OBB (ORIENTED BOUNDING BOX)
/// ============================================================================
///
/// // Lớp này chịu trách nhiệm cho toàn bộ quy trình từ ảnh thô đến kết quả đếm:
/// 1. [Pre-processing]: Letterboxing ảnh về 640x640 để không làm méo vật thể.
/// 2. [Inference]: Chạy mô hình TFLite trên nhân CPU/GPU.
/// 3. [Post-processing]: Giải mã Tensor đầu ra thành tọa độ thực (OBB).
/// 4. [NMS]: Loại bỏ các kết quả trùng lặp bằng thuật toán Rotated IoU.
/// 5. [Mapping]: Ánh xạ tọa độ từ khung 640x640 về kích thước ảnh gốc.
///
/// ============================================================================
///
/// [GIẢI THÍCH VỀ ĐẦU VÀO (INPUT TENSOR)]:
/// - Dạng mảng 4 chiều: [Batch_Size, Width, Height, Channels]
/// - Cụ thể trong code: [1, 640, 640, 3]
/// - Ý nghĩa: 1 ảnh mỗi lần chạy, kích thước 640x640 pixel, 3 kênh màu đỏ-xanh lá-xanh dương (RGB).
/// - Giá trị pixel: Đã được chuẩn hóa từ [0-255] về [0.0 - 1.0] dạng Float32.
///
/// [GIẢI THÍCH VỀ ĐẦU RA (OUTPUT TENSOR)]:
/// - Dạng mảng 3 chiều: [1, 21504, 7] (Số liệu có thể thay đổi nhẹ tùy phiên bản Model)
/// - Ý nghĩa 7 giá trị trong mỗi dự đoán (Feature Vector):
///   1. data[0]: Center X (Tọa độ tâm X của vật thể)
///   2. data[1]: Center Y (Tọa độ tâm Y của vật thể)
///   3. data[2]: Width (Chiều dài cạnh dài nhất của vật)
///   4. data[3]: Height (Chiều dài cạnh ngắn của vật)
///   5. data[4]: Confidence Score (Độ tin cậy từ 0.0 đến 1.0)
///   6. data[5]: Class ID (Số định danh loại vật thể: 0, 1, 2...)
///   7. data[6]: Angle (Góc xoay tính bằng Radian, thường từ -pi/2 đến pi/2)
///
/// ============================================================================

class CountingService {
  Interpreter? _interpreter; // Bộ máy thực thi mô hình AI (TensorFlow Lite)
  List<String> _labels = []; // Danh sách tên nhãn (ví dụ: 'bullet', 'shell'...)
  final _log = Logger('CountingService'); // Logger để theo dõi trạng thái hệ thống

  // --- BIẾN PHỤ TRỢ CHO LETTERBOXING ---
  // Dùng để ghi nhớ cách chúng ta đã biến đổi ảnh, phục vụ việc quy đổi ngược tọa độ.
  double _scale = 1.0; // Tỷ lệ thu nhỏ/phóng to ảnh gốc
  double _padX = 0;    // Khoảng cách bù lề đen bên trái/phải
  double _padY = 0;    // Khoảng cách bù lề đen bên trên/dưới

  // CẤU HÌNH THÔNG SỐ AI (HYPERPARAMETERS)
  static const int inputSize = 640;       // Kích thước đầu vào chuẩn của mô hình YOLOv11
  static const double confThreshold = 0.4; // Ngưỡng tin cậy tối thiểu để chấp nhận một vật thể
  static const double iouThreshold = 0.2;  // Ngưỡng chồng lấn tối đa giữa 2 vật thể trùng tên

  /// Khởi tạo Model từ mảng Bytes (Dùng khi chạy trong Isolate để tránh truy cập IO chậm)
  Future<void> loadModelFromBytes(Uint8List modelBytes, List<String> labels) async {
    if (_interpreter != null) return;
    try {
      // Khởi tạo trình thông dịch với 4 luồng xử lý để tối ưu tốc độ trên mobile
      _interpreter = Interpreter.fromBuffer(
        modelBytes,
        options: InterpreterOptions()..threads = 4,
      );
      _interpreter!.allocateTensors(); // Cấp phát bộ nhớ cho các Tensor đầu vào/đầu ra
      _labels = labels;
      _log.info("Model loaded successfully with ${_labels.length} labels.");
    } catch (e, stackTrace) {
      _log.severe('Failed to load the model', e, stackTrace);
      rethrow;
    }
  }

  /// HÀM CHÍNH: Thực hiện quy trình đếm đối tượng từ đường dẫn ảnh
  Future<List<DetectionResult>> countObjects(String imagePath, {int? targetClass}) async {
    if (_interpreter == null) return [];

    // --- BƯỚC 1: TIỀN XỬ LÝ ẢNH (PRE-PROCESSING VỚI LETTERBOXING) ---
    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return [];

    final double originalWidth = originalImage.width.toDouble();
    final double originalHeight = originalImage.height.toDouble();

    // Thuật toán Letterboxing: Tính toán scale để ảnh nằm gọn trong khung 640x640 mà không bị méo.
    // Ta lấy giá trị min của tỷ lệ rộng và cao.
    _scale = min(inputSize / originalWidth, inputSize / originalHeight);
    final int newW = (originalWidth * _scale).toInt();
    final int newH = (originalHeight * _scale).toInt();

    // Tính toán phần bù (Padding) để đưa ảnh đã resize vào chính giữa khung 640x640 đen.
    _padX = (inputSize - newW) / 2.0;
    _padY = (inputSize - newH) / 2.0;

    // Bước xử lý Pixel: Resize ảnh -> Tạo canvas đen -> Hợp nhất ảnh vào canvas.
    img.Image resizedImage = img.copyResize(originalImage, width: newW, height: newH);
    img.Image canvas = img.Image(width: inputSize, height: inputSize); // Mặc định là màu đen
    img.compositeImage(canvas, resizedImage, dstX: _padX.toInt(), dstY: _padY.toInt());

    // Chuyển đổi đối tượng Image sang mảng 4 chiều [1, 640, 640, 3] và chuẩn hóa [0.0 - 1.0]
    var input = _imageToArray(canvas);

    // --- BƯỚC 2: CHẠY SUY LUẬN (INFERENCE) ---
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final int numDetections = outputShape[1]; // Số lượng dự đoán (thường là 21504)
    final int numFeatures = outputShape[2];   // Số đặc trưng (7 giá trị: x, y, w, h, conf, class, angle)

    // Khởi tạo mảng chứa kết quả đầu ra
    var output = List.filled(numDetections * numFeatures, 0.0).reshape([1, numDetections, numFeatures]);

    // Thực thi mô hình AI
    _interpreter!.run(input, output);

    final List<DetectionResult> detectionsForNMS = [];

    // --- BƯỚC 3: PHÂN TÍCH VÀ TRÍCH XUẤT DỮ LIỆU (DECODING) ---
    for (var i = 0; i < numDetections; i++) {
      final data = output[0][i];
      final confidence = data[4];
      final classId = data[5].toInt();

      // Chỉ xử lý nếu độ tin cậy vượt ngưỡng và đúng loại class người dùng yêu cầu
      if (confidence > confThreshold) {
        if (targetClass == null || classId == targetClass) {
          // Tọa độ trả về từ AI là tọa độ chuẩn hóa trong khung 640x640
          final double cx = data[0] * inputSize;
          final double cy = data[1] * inputSize;
          double w = data[2] * inputSize;
          double h = data[3] * inputSize;
          double angle = data[6];

          // Đảm bảo tính nhất quán hình học: Cạnh W luôn là cạnh dài hơn để tính góc xoay chuẩn.
          if (w < h) {
            double temp = w; w = h; h = temp;
            angle += pi / 2;
          }

          // [TOÁN HỌC]: Chuyển đổi từ (Tâm, Rộng, Dài, Góc) sang 4 đỉnh thực tế trong khung 640.
          final List<Offset> vertices640 = _calculateRotatedVertices(cx, cy, w, h, angle);

          detectionsForNMS.add(DetectionResult(
            rotatedVertices: vertices640,
            confidence: confidence,
            classId: classId,
            className: classId < _labels.length ? _labels[classId] : 'Unknown',
            boundingBox: _calculateAABB(vertices640), // Khung chữ nhật đứng bao quanh (để tính toán nhanh)
          ));
        }
      }
    }

    // --- BƯỚC 4: LỌC TRÙNG VẬT THỂ (NON-MAXIMUM SUPPRESSION) ---
    // Sử dụng thuật toán NMS kết hợp với Rotated IoU để xử lý các hộp xoay nghiêng.
    List<DetectionResult> nmsResults = _nonMaximumSuppression(detectionsForNMS);

    // --- BƯỚC 5: QUY ĐỔI TỌA ĐỘ VỀ ẢNH GỐC (COORDINATE MAPPING) ---
    // Đây là bước quan trọng nhất để hiển thị kết quả đúng vị trí trên ảnh của người dùng.
    return nmsResults.map((res) {
      // Công thức: (Tọa độ trong khung AI - Lề đen) / Tỷ lệ scale ban đầu.
      final scaledVertices = res.rotatedVertices.map((p) {
        return Offset(
            (p.dx - _padX) / _scale,
            (p.dy - _padY) / _scale
        );
      }).toList();

      return DetectionResult(
        rotatedVertices: scaledVertices,
        confidence: res.confidence,
        classId: res.classId,
        className: res.className,
        boundingBox: _calculateAABB(scaledVertices),
      );
    }).toList();
  }

  // --------------------------------------------------------------------------
  // CÁC HÀM TOÁN HỌC & HÌNH HỌC PHỨC TẠP
  // --------------------------------------------------------------------------

  /// Tạo khung hình chữ nhật đứng (AABB) bao quanh 4 đỉnh xoay.
  Rect _calculateAABB(List<Offset> vertices) {
    if (vertices.isEmpty) return Rect.zero;
    double minX = vertices.map((p) => p.dx).reduce(min);
    double maxX = vertices.map((p) => p.dx).reduce(max);
    double minY = vertices.map((p) => p.dy).reduce(min);
    double maxY = vertices.map((p) => p.dy).reduce(max);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// [MA TRẬN XOAY]: Tính toán vị trí 4 đỉnh dựa trên tâm, kích thước và góc quay.
  /// Sử dụng công thức: x' = x*cos(θ) - y*sin(θ) | y' = x*sin(θ) + y*cos(θ)
  List<Offset> _calculateRotatedVertices(double cx, double cy, double w, double h, double angle) {
    final double cosA = cos(angle);
    final double sinA = sin(angle);
    // Tọa độ 4 đỉnh tương đối so với tâm (0,0)
    final points = [
      Offset(-w/2, -h/2), // Trên - Trái
      Offset(w/2, -h/2),  // Trên - Phải
      Offset(w/2, h/2),   // Dưới - Phải
      Offset(-w/2, h/2)   // Dưới - Trái
    ];
    // Xoay từng điểm và cộng thêm tọa độ tâm thực tế
    return points.map((p) => Offset(
        cx + p.dx * cosA - p.dy * sinA,
        cy + p.dx * sinA + p.dy * cosA
    )).toList();
  }

  /// [ROTATED IOU]: Tính tỷ lệ chồng lấn giữa 2 hình chữ nhật xoay.
  /// Khác với IoU thông thường, ở đây ta phải sử dụng thuật toán cắt đa giác.
  double _rotatedIoU(DetectionResult boxA, DetectionResult boxB) {
    final areaA = _getPolygonArea(boxA.rotatedVertices);
    final areaB = _getPolygonArea(boxB.rotatedVertices);
    if (areaA <= 0 || areaB <= 0) return 0.0;

    // Tìm vùng giao nhau bằng thuật toán Sutherland-Hodgman
    var intersection = boxA.rotatedVertices;
    for (int i = 0; i < boxB.rotatedVertices.length; i++) {
      final p1 = boxB.rotatedVertices[i];
      final p2 = boxB.rotatedVertices[(i + 1) % boxB.rotatedVertices.length];
      intersection = _clipPolygon(intersection, p1, p2);
      if (intersection.isEmpty) break;
    }

    final double interArea = _getPolygonArea(intersection);
    // Công thức IoU = Intersection / (AreaA + AreaB - Intersection)
    return interArea / (areaA + areaB - interArea);
  }

  /// [NMS]: Loại bỏ các dự đoán chồng chéo lên nhau để tránh đếm trùng.
  List<DetectionResult> _nonMaximumSuppression(List<DetectionResult> detections) {
    if (detections.isEmpty) return [];
    // Sắp xếp theo độ tin cậy giảm dần: Ưu tiên giữ lại các kết quả AI chắc chắn nhất.
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<DetectionResult> selected = [];
    final List<bool> active = List.filled(detections.length, true);

    for (int i = 0; i < detections.length; i++) {
      if (!active[i]) continue;
      selected.add(detections[i]);
      for (int j = i + 1; j < detections.length; j++) {
        // Chỉ so sánh các vật thể cùng loại (class)
        if (active[j] && detections[i].classId == detections[j].classId) {
          // Nếu trùng lấn quá nhiều (> 20%), loại bỏ kết quả có độ tin cậy thấp hơn.
          if (_rotatedIoU(detections[i], detections[j]) > iouThreshold) {
            active[j] = false;
          }
        }
      }
    }
    return selected;
  }

  /// [CLIPPING]: Thuật toán Sutherland-Hodgman để cắt đa giác.
  /// Dùng để tìm phần giao giữa 2 hình xoay nghiêng.
  List<Offset> _clipPolygon(List<Offset> subject, Offset p1, Offset p2) {
    List<Offset> output = [];
    final double dcx = p2.dx - p1.dx;
    final double dcy = p2.dy - p1.dy;
    for (int i = 0; i < subject.length; i++) {
      final cur = subject[i];
      final prev = subject[(i + subject.length - 1) % subject.length];
      final double curSide = (cur.dx - p1.dx) * dcy - (cur.dy - p1.dy) * dcx;
      final double prevSide = (prev.dx - p1.dx) * dcy - (prev.dy - p1.dy) * dcx;
      if (curSide <= 0) {
        if (prevSide > 0) {
          final double t = prevSide / (prevSide - curSide);
          output.add(Offset(prev.dx + t * (cur.dx - prev.dx), prev.dy + t * (cur.dy - prev.dy)));
        }
        output.add(cur);
      } else if (prevSide <= 0) {
        final double t = prevSide / (prevSide - curSide);
        output.add(Offset(prev.dx + t * (cur.dx - prev.dx), prev.dy + t * (cur.dy - prev.dy)));
      }
    }
    return output;
  }

  /// [DIỆN TÍCH]: Tính diện tích đa giác bằng công thức Shoelace (Dây giày).
  double _getPolygonArea(List<Offset> polygon) {
    if (polygon.length < 3) return 0.0;
    double area = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      area += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    return (area / 2.0).abs();
  }

  /// [TRANSFORM]: Chuyển đổi đối tượng Image sang mảng Tensor 4 chiều.
  /// Cấu trúc: [1 ảnh, 640 hàng, 640 cột, 3 màu RGB]
  List<List<List<List<double>>>> _imageToArray(img.Image image) {
    var input = List.generate(1, (_) =>
        List.generate(inputSize, (_) =>
            List.generate(inputSize, (_) => List.filled(3, 0.0))
        )
    );

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        // Chuẩn hóa từ 0-255 về 0.0-1.0 (Yêu cầu bắt buộc của mô hình Float32)
        input[0][y][x][0] = pixel.r / 255.0;
        input[0][y][x][1] = pixel.g / 255.0;
        input[0][y][x][2] = pixel.b / 255.0;
      }
    }
    return input;
  }

  /// Giải phóng tài nguyên mô hình khi không sử dụng để tránh rò rỉ bộ nhớ.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}