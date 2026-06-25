import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/services/api_service.dart';
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

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await TokenManager.loadFromStorage();
    final token = TokenManager.token;

    if (token == null || token.isEmpty) {
      _go(const LoginPage());
      return;
    }

    // 有 token → 调用 /auth/me 验证并获取用户信息
    try {
      final user = await ApiService().authMe();
      await TokenManager.setUser(user);
      final role = user.role;

      if (role == 'WORKER') {
        _go(const WorkerHomePage());
      } else if (role == 'CONTRACTOR') {
        _go(const ContractorHomePage());
      } else if (role == 'SITE_MANAGER' || role == 'PROJECT_MANAGER' || role == 'SUPER_ADMIN') {
        _go(const InternalHomePage());
      } else {
        _go(const AdminHomePage());
      }
    } catch (e) {
      await TokenManager.clear();
      _go(const LoginPage());
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
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('正在加载...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
