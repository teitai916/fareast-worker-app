import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/user_role.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/services/biometric_service.dart';
import 'package:fareast_worker_app/services/shortcut_service.dart';
import 'package:fareast_worker_app/pages/auth/login_page.dart';
import 'package:fareast_worker_app/pages/worker/worker_home_page.dart';
import 'package:fareast_worker_app/pages/contractor/contractor_home_page.dart';
import 'package:fareast_worker_app/pages/admin/admin_home_page.dart';
import 'package:fareast_worker_app/pages/internal/internal_home_page.dart';

/// 启动页：检查登录状态，决定跳转目标
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  static const Color _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  late final String _logTag = 'SplashPage';

  Future<void> _checkAuth() async {
    try {
      // 超时保护：5 秒内完成存储读取，超时不抛异常，按无 token 处理
      String? token;
      try {
        await TokenManager.loadFromStorage().timeout(
          const Duration(seconds: 5),
        );
        token = TokenManager.token;
      } catch (_) {
        debugPrint('[$_logTag] loadFromStorage 超时/异常，按无 token 处理');
        token = null;
      }

      await Future.delayed(const Duration(milliseconds: 1500));

      if (token == null || token.isEmpty) {
        // 无 token，先尝试生物识别自动登录
        try {
          final biometricAvailable = await BiometricService.isAvailable();
          if (biometricAvailable) {
            final success = await BiometricService.biometricLogin();
            if (success) {
              final user = TokenManager.currentUser;
              if (user != null && mounted) {
                final role = user.role;
                ShortcutService.setupForRole(role);
                if (role == 'WORKER') {
                  _go(const WorkerHomePage());
                } else if (role == 'CONTRACTOR') {
                  _go(const ContractorHomePage());
                } else if (UserRole.fromValue(role).isInternalStaff) {
                  _go(const InternalHomePage());
                } else {
                  _go(const AdminHomePage());
                }
                return;
              }
            }
          }
        } catch (_) {
          // 生物识别模块异常 → 忽略，正常走登录页
        }
        // 生物识别未启用/失败 → 进入登录页
        ShortcutService.setupForRole(null); // 清除快捷操作
        _go(const LoginPage());
        return;
      }

      // 有 token → 调用 /auth/me 验证并获取用户信息
      try {
        final user = await ApiService().authMe();
        await TokenManager.setUser(user);
        final role = user.role;

        // 根据角色设置快捷操作
        ShortcutService.setupForRole(role);

        if (role == 'WORKER') {
          _go(const WorkerHomePage());
        } else if (role == 'CONTRACTOR') {
          _go(const ContractorHomePage());
        } else if (UserRole.fromValue(role).isInternalStaff) {
          _go(const InternalHomePage());
        } else {
          _go(const AdminHomePage());
        }
      } catch (e) {
        await TokenManager.clear();
        ShortcutService.setupForRole(null); // 清除快捷操作
        _go(const LoginPage());
      }
    } catch (e) {
      // 底层存储初始化等任何异常 → 兜底进入登录页，避免 splash 卡死
      debugPrint('[$_logTag] _checkAuth 异常fallback: $e');
      ShortcutService.setupForRole(null);
      if (mounted) _go(const LoginPage());
    }
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo - 白底 + 亮蓝渐变光晕
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withOpacity(0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: _blue.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo_primary.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '遠東智工',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'FAREAST WORKER APP',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF64748B).withOpacity(0.5),
                    letterSpacing: 4,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '以幕牆科技，建安全工地',
                  style: TextStyle(
                    fontSize: 14,
                    color: _blue.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_blue.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
