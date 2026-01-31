// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bullet_counter/main.dart';

// 2. Tạo một danh sách camera giả để sử dụng trong các bài test
final mockCameras = [
  const CameraDescription(
    name: 'mock_cam_0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  ),
];

void main() {
  // 3. Sử dụng TestWidgetsFlutterBinding để cho phép giả lập các dịch vụ nền tảng
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 4. Truyền camera giả vào MyApp
    await tester.pumpWidget(MyApp(camera: mockCameras.first));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
