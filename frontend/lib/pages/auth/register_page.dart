import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  final String? initialRole;
  const RegisterPage({super.key, this.initialRole});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneController = TextEditingController();
  final _chineseNameController = TextEditingController();
  final _englishNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _api = ApiService();

  /// 是否由上一頁預選了角色（只讀，不可修改）
  bool get _rolePreselected => _effectiveRole != null;
  String? _effectiveRole;
  String _selectedRole = 'WORKER';

  List<dynamic> _companies = [];
  int? _selectedCompanyId;
  bool _loadingCompanies = false;

  bool _loading = false;
  bool _sendingCode = false;
  bool _obscurePassword = true;
  bool _agreed = false;
  String? _countdownText;
  int _countdown = 0;
  DateTime? _birthDate;
  String _countryCode = '+852';
  static const _hkPhoneLength = 8;
  static const _cnPhoneLength = 11;

  @override
  void initState() {
    super.initState();
    _restoreCountdown();
    // widget.initialRole 在 initState 時已可用
    if (widget.initialRole == 'CONTRACTOR' || widget.initialRole == 'WORKER') {
      _effectiveRole = widget.initialRole;
      _selectedRole = widget.initialRole!;
    }
    // 只有判頭才需要加載公司列表
    if (_selectedRole == 'CONTRACTOR') {
      _loadCompanies();
    }
  }

  Future<void> _restoreCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt('sms_countdown_end');
    if (endTime != null) {
      final remaining = endTime - DateTime.now().millisecondsSinceEpoch;
      if (remaining > 0) {
        final seconds = (remaining ~/ 1000) + 1;
        setState(() { _countdown = seconds; _countdownText = '$seconds秒'; });
        _runCountdown();
      } else {
        prefs.remove('sms_countdown_end');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 若 widget.initialRole 未預選，嘗試從路由 arguments 讀取（兼容舊用法）
    if (_effectiveRole == null) {
      final arg = ModalRoute.of(context)?.settings.arguments as String?;
      if (arg == 'CONTRACTOR' || arg == 'WORKER') {
        setState(() {
          _effectiveRole = arg;
          _selectedRole = arg!;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _chineseNameController.dispose();
    _englishNameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    try {
      final data = await _api.getCompanies();
      if (!mounted) return;
      setState(() => _companies = data);
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加載公司列表失敗：${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    final expectedLength = _countryCode == '+86' ? _cnPhoneLength : _hkPhoneLength;
    if (phone.isEmpty || phone.length != expectedLength || !RegExp(r'^\d+$').hasMatch(phone)) {
      _showMsg('请输入${expectedLength}位有效手机号');
      return;
    }
    setState(() { _sendingCode = true; });
    try {
      await _api.sendSms(phone);
      if (!mounted) return;
      _showMsg('短信驗證碼已發送到您註冊的手機號');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      _showMsg(msg);
    } finally {
      if (mounted) setState(() { _sendingCode = false; });
    }
  }

  void _startCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = DateTime.now().millisecondsSinceEpoch + 120000;
    prefs.setInt('sms_countdown_end', endTime);
    setState(() { _countdown = 120; _countdownText = '120秒'; });
    _runCountdown();
  }

  void _runCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _countdown <= 0) {
        if (mounted) setState(() { _countdownText = null; });
        SharedPreferences.getInstance().then((p) => p.remove('sms_countdown_end'));
        return false;
      }
      setState(() { _countdown--; _countdownText = '$_countdown秒'; });
      return true;
    });
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1980, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: '選擇出生日期',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (picked != null && picked != _birthDate) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _register() async {
    final phone = _phoneController.text.trim();
    final chineseName = _chineseNameController.text.trim();
    final englishName = _englishNameController.text.trim();
    final code = _codeController.text.trim();
    final pwd = _passwordController.text;
    final confirm = _confirmController.text;

    if (phone.isEmpty || phone.length != (_countryCode == '+86' ? _cnPhoneLength : _hkPhoneLength) || !RegExp(r'^\d+$').hasMatch(phone)) {
      _showMsg('请输入${_countryCode == '+86' ? _cnPhoneLength : _hkPhoneLength}位有效手机号'); return;
    }
    if (chineseName.isEmpty) {
      _showMsg('請輸入中文姓名'); return;
    }
    if (englishName.isEmpty) {
      _showMsg('請輸入英文姓名'); return;
    }
    if (_birthDate == null) {
      _showMsg('請選擇出生日期'); return;
    }
    if (code.isEmpty || code.length != 6) {
      _showMsg('請輸入6位驗證碼'); return;
    }
    if (pwd.isEmpty || pwd.length < 6) {
      _showMsg('密碼長度不少於6位'); return;
    }
    if (pwd != confirm) {
      _showMsg('兩次輸入的密碼不一致'); return;
    }
    if (!_agreed) {
      _showMsg('請同意《用戶協議》和《隱私政策》'); return;
    }
    if (_selectedRole == 'CONTRACTOR' && _selectedCompanyId == null) {
      _showMsg('請選擇所屬公司'); return;
    }

    setState(() => _loading = true);
    try {
      await _api.register(
        phone: phone,
        password: pwd,
        code: code,
        chineseName: chineseName,
        englishName: englishName,
        role: _selectedRole,
        companyId: _selectedCompanyId,
        countryCode: _countryCode,
        birthDate: _birthDate != null
            ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊成功'), backgroundColor: Colors.green),
      );
      // 按角色跳轉
      if (!mounted) return;
      if (_selectedRole == 'WORKER') {
        Navigator.pushReplacementNamed(context, '/worker/home');
      } else {
        Navigator.pushReplacementNamed(context, '/contractor/home');
      }
    } catch (e) {
      if (!mounted) return;
      _showMsg('註冊失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用戶註冊'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('創建帳號', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('請填寫以下信息完成註冊',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 28),

              // 手機號碼（含區號選擇）
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 區號選擇
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: _countryCode,
                      decoration: InputDecoration(
                        labelText: '區號',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: '+852', child: Text('+852')),
                        DropdownMenuItem(value: '+86', child: Text('+86')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _countryCode = v;
                            _phoneController.clear();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 手機號碼輸入
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: _countryCode == '+86' ? 11 : 8,
                      decoration: InputDecoration(
                        labelText: '手機號碼 *',
                        hintText: _countryCode == '+86' ? '內地手機號碼' : '香港手機號碼',
                        prefixIcon: const Icon(Icons.phone_android),
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 驗證碼行
              SizedBox(
                height: 56,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: '驗證碼 *',
                          prefixIcon: const Icon(Icons.sms_outlined),
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: ElevatedButton(
                        onPressed: (_sendingCode || _countdown > 0) ? null : _sendCode,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _countdownText ?? '獲取驗證碼',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),

              // 中文姓名
              TextFormField(
                controller: _chineseNameController,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '中文姓名 *',
                  hintText: '身份證上的中文姓名',
                  prefixIcon: const Icon(Icons.person_outline),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // 英文姓名
              TextFormField(
                controller: _englishNameController,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '英文姓名 *',
                  hintText: '護照上的英文姓名',
                  prefixIcon: const Icon(Icons.person_outline),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // 出生日期
              Text('出生日期 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.textHint, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _birthDate != null
                            ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
                            : '請選擇出生日期',
                        style: TextStyle(
                          fontSize: 16,
                          color: _birthDate != null ? AppTheme.textPrimary : AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 角色選擇
              Text('註冊身份 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              if (_rolePreselected)
                // 已預選角色：只讀展示
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _effectiveRole == 'WORKER' ? Icons.engineering : Icons.business,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _effectiveRole == 'WORKER' ? '工人' : '判頭',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
                    ],
                  ),
                )
              else
                // 未預選：可互動選擇
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('工人')),
                        selected: _selectedRole == 'WORKER',
                        onSelected: (_) {
                          setState(() {
                            _selectedRole = 'WORKER';
                            _companies = [];
                            _selectedCompanyId = null;
                          });
                        },
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _selectedRole == 'WORKER' ? AppTheme.primaryColor : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('判頭')),
                        selected: _selectedRole == 'CONTRACTOR',
                        onSelected: (_) {
                          setState(() {
                            _selectedRole = 'CONTRACTOR';
                          });
                          _loadCompanies();
                        },
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _selectedRole == 'CONTRACTOR' ? AppTheme.primaryColor : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // 公司選擇（判頭專用）
              if (_selectedRole == 'CONTRACTOR') ...[
                Text('所屬公司 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                _loadingCompanies
                    ? const Center(child: SizedBox(height: 48, child: CircularProgressIndicator(strokeWidth: 2)))
                    : DropdownButtonFormField<int>(
                        value: _selectedCompanyId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: '所屬公司 *',
                          prefixIcon: const Icon(Icons.business_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        hint: const Text('請選擇所屬公司'),
                        items: _companies.map<DropdownMenuItem<int>>((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['name'] ?? ''),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedCompanyId = v),
                      ),
                const SizedBox(height: 16),
              ],

              // 密碼
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '設置密碼 *',
                  hintText: '不少於6位',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textHint,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // 確認密碼
              TextFormField(
                controller: _confirmController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '確認密碼 *',
                  hintText: '再次輸入密碼',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // 同意條款
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: const Text.rich(
                        TextSpan(
                          text: '我已閱讀並同意《',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                          children: [
                            TextSpan(text: '用戶協議', style: TextStyle(color: AppTheme.primaryColor)),
                            TextSpan(text: '》和《'),
                            TextSpan(text: '隱私政策', style: TextStyle(color: AppTheme.primaryColor)),
                            TextSpan(text: '》', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 註冊按鈕
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('註冊', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              // 返回登入
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('已有帳號？', style: TextStyle(color: AppTheme.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('立即登入'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
