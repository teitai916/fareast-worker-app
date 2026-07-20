import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fareast_worker_app/app.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/services/shortcut_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 锁定竖屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  // 加载本地存储的登录状态（带 3 秒超时保护）
  try {
    await TokenManager.loadFromStorage().timeout(
      const Duration(seconds: 3),
      onTimeout: () => debugPrint('main: loadFromStorage 超时，跳过'),
    );
  } catch (_) {
    debugPrint('main: loadFromStorage 异常，跳过');
  }
  // 初始化快捷操作监听
  ShortcutService.init();
  runApp(const App());
}
