import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_android_dex/services/app_logger.dart';
import 'package:open_android_dex/services/dependency_manager_service.dart';

void main() {
  group('AppLogger & DependencyManager Tests', () {
    test('AppLogger initializes and logs messages to memory and file', () {
      AppLogger.init();
      AppLogger.info('Test info message for unit test');
      AppLogger.warning('Test warning message');
      AppLogger.error('Test error message', Exception('Test exception'));

      final logs = AppLogger.recentLogs;
      expect(logs, isNotEmpty);
      expect(logs.any((l) => l.contains('Test info message')), isTrue);
      expect(logs.any((l) => l.contains('Test warning message')), isTrue);
      expect(logs.any((l) => l.contains('Test error message')), isTrue);

      final logFile = File(AppLogger.logFilePath);
      expect(logFile.existsSync(), isTrue);
      final fileContent = logFile.readAsStringSync();
      expect(fileContent.contains('Test info message'), isTrue);
    });

    test('DependencyManager checks dependencies gracefully', () async {
      final depMgr = DependencyManagerService();
      final ready = await depMgr.checkDependencies();
      expect(ready, isA<bool>());
      expect(depMgr.isChecking, isFalse);
    });
  });
}
