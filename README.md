# Bullet Counter 🎯

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![YOLO](https://img.shields.io/badge/YOLO11--OBB-00FFFF)](https://github.com/ultralytics/ultralytics)
[![TFLite](https://img.shields.io/badge/TensorFlow-Lite-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Ứng dụng di động đếm vật thể tự động sử dụng YOLO11-OBB và Flutter**

Bullet Counter là giải pháp đếm vật thể chính xác cao được xây dựng bằng Flutter, tích hợp mô hình YOLO11-OBB (Oriented Bounding Box) để nhận diện và đếm số lượng vật thể từ hình ảnh tĩnh. Ứng dụng đặc biệt hữu ích cho việc đếm các vật thể nhỏ có định hướng như viên đạn, linh kiện điện tử, sản phẩm công nghiệp, v.v.

---

## ✨ Tính năng chính

- 📸 **Chụp ảnh và phân tích**: Sử dụng camera để chụp ảnh, sau đó phát hiện và đếm vật thể
- 🖼️ **Chọn ảnh từ thư viện**: Hỗ trợ phân tích ảnh có sẵn (Image Picker)
- 🎯 **Độ chính xác cao**: Sử dụng YOLO11-OBB cho việc nhận diện vật thể có hướng (rotated objects)
- 🎨 **Giao diện trực quan**: Hiển thị bounding boxes và kết quả đếm ngay trên ảnh
- 📊 **Tùy chỉnh hiển thị đa dạng**:
    - Hiển thị/ẩn bounding boxes
    - Hiển thị/ẩn confidence score
    - Fill màu bên trong box với opacity tùy chỉnh
    - Hiển thị số thứ tự từng vật thể
    - Chế độ đa màu (mỗi vật thể một màu khác nhau)
    - Tùy chỉnh màu sắc bounding box
- 📸 **Screenshot & Lưu**: Chụp màn hình kết quả và lưu vào thư viện ảnh
- 💾 **Lưu trữ cấu hình**: Preferences service để lưu cài đặt người dùng
- 📝 **Logging system**: Theo dõi và debug với logging service

---

## 🧠 Công nghệ AI - YOLO11-OBB

### Tại sao sử dụng YOLO11-OBB?

**YOLO11-OBB** (Oriented Bounding Box) là phiên bản mới nhất của YOLO, được tối ưu hóa đặc biệt cho việc phát hiện các vật thể có hướng:

- **OBB vs Standard BBox**:
    - Standard bbox: Chỉ có thể tạo hộp vuông thẳng (x, y, width, height)
    - OBB: Tạo hộp xoay theo góc của vật thể (x, y, width, height, angle)

- **Ưu điểm cho đếm đạn**:
    - Viên đạn thường nằm theo nhiều hướng khác nhau
    - OBB giảm overlap giữa các bounding boxes
    - Tăng độ chính xác phát hiện khi vật thể xếp chồng lên nhau

- **Hiệu năng**:
    - Tốc độ xử lý: ~10s/ảnh trên thiết bị trung cấp
    - Độ chính xác: mAP > 90% (tùy dataset huấn luyện)

### Xử lý đa luồng với Isolate

Ứng dụng sử dụng **Dart Isolate** để tối ưu hóa hiệu năng và trải nghiệm người dùng:

- **Background Processing**: AI inference được thực thi trên luồng phụ (background isolate), không block UI thread
- **Responsive UI**: Giao diện luôn mượt mà, người dùng có thể tương tác trong khi AI đang xử lý
- **Memory Management**: Isolate giúp quản lý bộ nhớ hiệu quả hơn, tránh tình trạng lag hoặc crash khi xử lý ảnh lớn
- **Parallel Processing**: Có thể xử lý nhiều tác vụ đồng thời mà không ảnh hưởng đến nhau

> 💡 **Kỹ thuật**: Mô hình TFLite và việc pre-processing/post-processing ảnh đều được thực hiện trên isolate riêng biệt, đảm bảo trải nghiệm người dùng mượt mà ngay cả khi xử lý ảnh độ phân giải cao.

---

## 🛠️ Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Framework** | Flutter (Dart) | 3.10.1+ |
| **AI Model** | YOLO11-OBB | Latest |
| **ML Runtime** | TensorFlow Lite | ^0.12.1 |
| **Camera** | camera | ^0.11.3 |
| **State Management** | provider | ^6.0.5 |
| **Image Processing** | image | ^4.1.3 |
| **Storage** | path_provider | ^2.1.5 |
| **Permissions** | permission_handler | ^11.3.1 |
| **Preferences** | shared_preferences | ^2.2.2 |
| **Screenshot** | screenshot | ^3.0.0 |
| **Logging** | logging | ^1.2.0 |

---

## 📁 Cấu trúc dự án

```
bullet_counter/
├── android/                      # Android native code
├── ios/                         # iOS native code
├── assets/                      # Model & resources
│   ├── yolo11m_obb_bullet_couter_preview_float32.tflite
│   ├── yolo11m_obb_bullet_couter_preview_float16.tflite
│   ├── labels.txt              # Class labels
│   ├── fonts/                  # Custom fonts
│   └── images/                 # UI assets & icons
├── lib/
│   ├── main.dart               # App entry point
│   ├── helpers/                # Utility helpers
│   │   └── ui_helpers.dart
│   ├── models/                 # Data models
│   │   ├── detection_result.dart
│   │   └── processed_detection.dart
│   ├── screens/                # UI screens
│   │   ├── bounding_box_painter.dart
│   │   ├── camera_screen.dart
│   │   └── counting_screen.dart
│   ├── services/               # Business logic
│   │   ├── camera_service.dart
│   │   ├── counting_service.dart
│   │   ├── detection_processor.dart
│   │   └── preferences_service.dart
│   ├── utils/                  # Utilities
│   │   └── logger.dart
│   └── widgets/                # Reusable widgets
│       ├── camera_bottom_toolbar.dart
│       ├── menu_display_options.dart
│       └── menu_mode_selector.dart
├── test/                       # Unit & widget tests
└── pubspec.yaml               # Dependencies & assets
```

---

## 🚀 Cài đặt & Chạy

### 1. Yêu cầu hệ thống

- **Flutter SDK**: 3.10.1 trở lên
- **Dart**: 3.10.1+
- **RAM**: Tối thiểu 4GB (khuyến nghị 8GB+)
- **OS**: Windows 10/11, macOS 10.14+, hoặc Linux
- **Storage**: ~500MB cho dependencies và models

**Kiểm tra cài đặt Flutter:**
```bash
flutter doctor -v
```

### 2. Clone & Setup

```bash
# Clone repository
git clone https://github.com/daovietduc/bullet_counter_1.1.0
cd bullet_counter

# Cài đặt dependencies
flutter pub get

# Kiểm tra devices
flutter devices
```

### 3. Chuẩn bị Model AI

#### Tải model có sẵn (Khuyến nghị)
1. Tải models đã huấn luyện từ [Releases](https://github.com/daovietduc/bullet_counter_1.1.0/releases)
2. Đặt file vào thư mục `assets/`:
   ```
   assets/
   ├── yolo11m_obb_bullet_couter_preview_float32.tflite
   ├── yolo11m_obb_bullet_couter_preview_float16.tflite
   ├── labels.txt                # Class: "bullet"
   ├── fonts/                    # Custom fonts
   └── images/                   # UI assets
   ```

3. **Chọn model trong code**: Mở `lib/services/detection_processor.dart` và chọn model phù hợp:
   ```dart
   // Thay đổi tên model file
   static const String modelPath = 'assets/yolo11m_obb_bullet_couter_preview_float16.tflite';
   ```

#### Hoặc sử dụng model tùy chỉnh

Nếu bạn có model YOLO11-OBB đã huấn luyện riêng:
1. Export model sang TFLite format
2. Đổi tên file và đặt vào `assets/`
3. Cập nhật `modelPath` trong `detection_processor.dart`
4. Cập nhật `pubspec.yaml` để include file model mới

### 4. Cấu hình Native

#### Android (android/app/src/main/AndroidManifest.xml)
```xml
<manifest>
    <!-- Camera permission -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Storage permissions (for image_gallery_saver_plus) -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
                     android:maxSdkVersion="32" />
    
    <!-- Android 13+ permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    
    <!-- Camera feature -->
    <uses-feature android:name="android.hardware.camera" android:required="true" />
    
    <application
        android:requestLegacyExternalStorage="true">
        <!-- ... -->
    </application>
</manifest>
```

#### iOS (ios/Runner/Info.plist)
```xml
<dict>
    <!-- Camera usage description -->
    <key>NSCameraUsageDescription</key>
    <string>Ứng dụng cần truy cập camera để chụp ảnh và đếm vật thể</string>
    
    <!-- Photo Library usage (for image_picker) -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Ứng dụng cần truy cập thư viện ảnh để chọn và phân tích ảnh</string>
    
    <!-- Photo Library Add usage (for image_gallery_saver_plus) -->
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Ứng dụng cần quyền lưu kết quả phân tích vào thư viện ảnh</string>
</dict>
```

### 5. Build & Run

```bash
# Run in debug mode
flutter run

# Build release APK (Android)
flutter build apk --release

# Build iOS (requires macOS & Xcode)
flutter build ios --release
```

---

## 📱 Hướng dẫn sử dụng

### Cách 1: Chụp ảnh mới
1. **Mở ứng dụng** → Chế độ "Camera"
2. **Chụp ảnh** → Nhấn nút chụp để chụp ảnh vật thể cần đếm
3. **Phân tích** → Nhấn nút COUNT để AI thực hiện phân tích
4. **Xem kết quả** → Bounding boxes hiển thị trên ảnh với số lượng được đếm

### Cách 2: Chọn ảnh có sẵn
1. **Mở ứng dụng** → Nhấn biểu tượng thư viện ảnh
2. **Chọn ảnh** → Chọn ảnh từ thư viện điện thoại
3. **Phân tích** → Nhấn nút COUNT để AI thực hiện phân tích
4. **Xem kết quả** → Bounding boxes hiển thị trên ảnh với số lượng được đếm

### Các tính năng bổ sung
- **Screenshot**: Nhấn nút screenshot để lưu kết quả
- **Lưu vào thư viện**: Kết quả tự động lưu vào Photos/Gallery
- **Tùy chỉnh hiển thị**: Menu để điều chỉnh cách hiển thị bounding boxes (xem phần bên dưới)

### Screenshots

<table>
  <tr>
    <td><img src="screenshots/camera_screen.png" width="200"/><br/><i>Camera Screen</i></td>
    <td><img src="screenshots/detection_result.png" width="200"/><br/><i>Detection Result</i></td>
    <td><img src="screenshots/counting_display.png" width="200"/><br/><i>Counting Display</i></td>
  </tr>
</table>

> 💡 **Tip**: Để có kết quả tốt nhất, chụp ảnh trong điều kiện ánh sáng tốt, camera ổn định và vật thể nằm trong khung hình rõ ràng.

---

## ⚙️ Cấu hình & Tùy chỉnh

### 1. Tùy chỉnh Hiển thị Kết quả

Ứng dụng cung cấp nhiều tùy chọn hiển thị linh hoạt cho bounding boxes và kết quả phát hiện:

| Chức năng | Mô tả |
|-----------|-------|
| **Hiển thị Bounding Box** | Bật/tắt hiển thị khung bao quanh vật thể |
| **Hiển thị Confidence Score** | Hiển thị điểm tin cậy (%) của mỗi detection |
| **Fill Box** | Tô màu bên trong bounding box |
| **Độ trong suốt Fill** | Điều chỉnh độ mờ của màu fill (0% - 100%) |
| **Hiển thị số thứ tự** | Hiển thị số thứ tự từng vật thể (1, 2, 3...) |
| **Chế độ đa màu** | Mỗi vật thể hiển thị một màu khác nhau (rainbow mode) |
| **Tùy chỉnh màu Box** | Chọn màu sắc của bounding box |

Các tùy chọn này được điều chỉnh qua menu hiển thị trong ứng dụng.

### 2. Tùy chỉnh UI Widgets

Các widget có thể tùy chỉnh trong `lib/widgets/`:
- `camera_bottom_toolbar.dart`: Thanh công cụ dưới camera
- `menu_display_options.dart`: Menu tùy chọn hiển thị (chứa các toggle cho options trên)
- `menu_mode_selector.dart`: Bộ chọn chế độ

---

## 🔄 Roadmap

### ✅ Đã hoàn thành (v1.1.0)
- [x] Chụp ảnh qua camera
- [x] Chọn ảnh từ thư viện
- [x] Phát hiện OBB với YOLO11
- [x] 7 tùy chọn hiển thị linh hoạt
- [x] Screenshot kết quả
- [x] Lưu ảnh vào thư viện
- [x] Custom fonts và UI polish
- [x] Logging system
- [x] Preferences service

### 🚧 Đang phát triển (v1.1.1)
- [ ] History: Xem lại các lần đếm trước
- [ ] Flash: Chế độ flash
- [ ] Tỷ lệ camera (4:3, 16:9)
- [ ] Multi-language (English, Vietnamese)

### 📋 Kế hoạch tương lai
- [ ] **v1.2**: Support nhiều object classes (không chỉ bullets)
- [ ] **v2.0**: Real-time video counting

---

## 📄 License

Dự án này được phân phối dưới giấy phép **MIT License** - xem file [LICENSE](LICENSE) để biết chi tiết.

```
MIT License - Copyright (c) 2024 Đào Việt Đức
```

---

## 📧 Liên hệ

**Đào Việt Đức**

- 📘 Facebook: [duc.boderguard](https://www.facebook.com/duc.boderguard/)
- 📧 Email: daovietduc.bdbp@gmail.com
- 🐙 GitHub: [@daovietduc](https://github.com/daovietduc)

---

## 🙏 Acknowledgments

- [Ultralytics YOLO11](https://github.com/ultralytics/ultralytics) - YOLO model
- [TensorFlow Lite](https://www.tensorflow.org/lite) - Model optimization
- [Flutter](https://flutter.dev) - Cross-platform framework

---

<div align="center">

**⭐ Nếu project này hữu ích, hãy cho một star nhé! ⭐**

Made with ❤️ by Đào Việt Đức

</div>
