import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/widgets/app_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    try {
      await _api.sendSms(_phoneController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('驗證碼已發送'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('發送失敗：$e')));
      }
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.resetPassword(
        _phoneController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密碼重設成功'), backgroundColor: AppTheme.successColor),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重設失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('忘記密碼'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '重設密碼',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                '請輸入手機號碼，我們將發送驗證碼給您',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),

              AppTextField(
                controller: _phoneController,
                label: '手機號碼',
                hintText: '請輸入註冊時的手機號碼',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_android),
                maxLength: 11,
                validator: (v) => v == null || v.isEmpty ? '請輸入手機號碼' : null,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _codeController,
                      label: '驗證碼',
                      hintText: '請輸入驗證碼',
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) => v == null || v.isEmpty ? '請輸入驗證碼' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: CodeButton(onPressed: _sendCode),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              AppTextField(
                controller: _passwordController,
                label: '新密碼',
                hintText: '請輸入新密碼（至少6位）',
                obscureText: _obscurePassword,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textHint),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '請輸入新密碼';
                  if (v.length < 6) return '密碼長度不少於6位';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              AppTextField(
                controller: _confirmPasswordController,
                label: '確認新密碼',
                hintText: '請再次輸入新密碼',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: (v) {
                  if (v == null || v.isEmpty) return '請確認新密碼';
                  if (v != _passwordController.text) return '兩次輸入的密碼不一致';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              AppButton(text: '重設密碼', onPressed: _reset, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
