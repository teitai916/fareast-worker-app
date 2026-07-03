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
  // 加载本地存储的登录状态
  await TokenManager.loadFromStorage();
  // 初始化快捷操作监听
  ShortcutService.init();
  runApp(const App());
}
