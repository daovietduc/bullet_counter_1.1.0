import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart'; // Thêm dòng này

// Tạo một logger cấp cao nhất cho ứng dụng của bạn
final log = Logger('MyApp');

void setupLogging() {
  // Chỉ hiển thị log khi ở chế độ debug
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Chỉ in ra console nếu đang ở chế độ debug
    if (kDebugMode) {
      print('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        print('   ERROR: ${record.error}');
      }
      if (record.stackTrace != null) {
        print('   STACKTRACE: ${record.stackTrace}');
      }
    }
  });
}
    