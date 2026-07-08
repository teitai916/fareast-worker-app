import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            counterText: '',
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppTheme.primaryColor,
          foregroundColor: textColor ?? Colors.white,
          disabledBackgroundColor: AppTheme.dividerColor,
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(text),
      ),
    );
  }
}

class CodeButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool loading;

  const CodeButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<CodeButton> createState() => _CodeButtonState();
}

class _CodeButtonState extends State<CodeButton> {
  int _countdown = 0;
  static const String _prefsKey = 'sms_countdown_end';
  static const int _countdownSeconds = 120;

  @override
  void initState() {
    super.initState();
    _restoreCountdown();
  }

  Future<void> _restoreCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt(_prefsKey);
    if (endTime != null) {
      final remaining = endTime - DateTime.now().millisecondsSinceEpoch;
      if (remaining > 0) {
        setState(() => _countdown = (remaining ~/ 1000) + 1);
        _runCountdown();
      } else {
        prefs.remove(_prefsKey);
      }
    }
  }

  void _runCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        SharedPreferences.getInstance().then((p) => p.remove(_prefsKey));
        return false;
      }
      return true;
    });
  }

  void startCountdown() {
    if (_countdown > 0) return;
    final endTime = DateTime.now().millisecondsSinceEpoch + _countdownSeconds * 1000;
    SharedPreferences.getInstance().then((p) => p.setInt(_prefsKey, endTime));
    setState(() => _countdown = _countdownSeconds);
    _runCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _countdown > 0 || widget.loading ? null : () {
        widget.onPressed();
        startCountdown();
      },
      child: widget.loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _countdown > 0 ? '${_countdown}s' : '獲取驗證碼',
              style: TextStyle(
                color: _countdown > 0 ? AppTheme.textHint : AppTheme.primaryColor,
                fontSize: 14,
              ),
            ),
    );
  }
}
