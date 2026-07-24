import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/user_role.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/services/biometric_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _blue = Color(0xFF2563EB);
  bool _biometricReady = false;
  bool _biometricLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    debugPrint('[LoginPage] 检查生物识别...');
    final available = await BiometricService.isAvailable();
    debugPrint('[LoginPage] isAvailable=$available');
    if (!available) return;
    final enabled = await BiometricService.isBiometricEnabled();
    debugPrint('[LoginPage] isBiometricEnabled=$enabled');
    if (!enabled) return;
    if (!mounted) return;
    setState(() => _biometricReady = true);
  }

  Future<void> _biometricLogin() async {
    setState(() => _biometricLoading = true);
    final success = await BiometricService.biometricLogin();
    if (!mounted) return;
    setState(() => _biometricLoading = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('指紋登入失敗，請使用密碼登入')),
      );
      return;
    }
    _navigateByRole();
  }

  void _navigateByRole() {
    final user = TokenManager.currentUser; // from api_service.dart
    if (user == null) return;
    final role = user.role;
    if (role == 'WORKER') {
      Navigator.pushReplacementNamed(context, '/worker/home');
    } else if (role == 'CONTRACTOR') {
      Navigator.pushReplacementNamed(context, '/contractor/home');
    } else if (UserRole.fromValue(role).isInternalStaff) {
      Navigator.pushReplacementNamed(context, '/internal/home');
    } else {
      Navigator.pushReplacementNamed(context, '/admin/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Logo - 白底 + 亮蓝渐变光晕
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: _blue.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/logo_primary.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '遠東智工',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
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

              // ── 登入按鈕（置頂，方便老用戶快速登入）──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login-form'),
                  icon: const Icon(Icons.login, size: 20, color: Colors.white),
                  label: const Text('手機號碼登入', style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Biometric login button (only when enabled and available)
              if (_biometricReady)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _biometricLoading ? null : _biometricLogin,
                    icon: _biometricLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint, size: 20),
                    label: Text(_biometricLoading ? '驗證中...' : '指紋/面容登入', style: const TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              const SizedBox(height: 40),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('新用戶註冊', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Welcome message
              const Text(
                '請選擇您的身份以繼續',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Role Selection Cards
              _buildRoleCard(
                icon: Icons.engineering,
                title: '工人',
                subtitle: '地盤工人 • 考勤打卡 • 安全培訓',
                color: const Color(0xFF2563EB),
                onTap: () => Navigator.pushNamed(context, '/register', arguments: 'WORKER'),
              ),
              const SizedBox(height: 12),
              _buildRoleCard(
                icon: Icons.business,
                title: '分判商 (判頭)',
                subtitle: '地盤管理 • 工人審核 • 考勤查看',
                color: const Color(0xFF059669),
                onTap: () => Navigator.pushNamed(context, '/register', arguments: 'CONTRACTOR'),
              ),
              const SizedBox(height: 12),
              _buildRoleCard(
                icon: Icons.admin_panel_settings,
                title: '內部工作人員',
                subtitle: '平台管理 • 安全監控 • 審批管理',
                color: const Color(0xFF7C3AED),
                onTap: () => _showInternalLoginDialog(),
              ),
              const SizedBox(height: 32),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('用戶協議', style: TextStyle(fontSize: 12)),
                  ),
                  const Text('|', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('私隱政策', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          debugPrint('Navigating as $title');
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_ios, color: color, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInternalLoginDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '內部工作人員登入',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '請選擇登入方式',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/login-form');
                },
                icon: const Icon(Icons.phone_android),
                label: const Text('手機號碼登入'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正在跳轉到飛書授權...')),
                  );
                },
                icon: const Icon(Icons.book),
                label: const Text('使用飛書免密登入'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
