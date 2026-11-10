import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'services/adb_service.dart';
import 'services/app_logger.dart';
import 'views/dex_desktop_screen.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  if (args.contains('--demo') || args.contains('--mock')) {
    AdbService().enableDemoMode();
  }
  runApp(const OpenAndroidDexApp());
}

/// Custom scroll behavior enabling two-finger trackpad, mouse, and touch scrolling everywhere.
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class OpenAndroidDexApp extends StatelessWidget {
  const OpenAndroidDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Android Dex',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const DesktopScrollBehavior(),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF131824),
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const DexDesktopScreen(),
    );
  }
}
