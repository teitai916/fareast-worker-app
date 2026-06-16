import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class WorkerRegisterPage extends StatefulWidget {
  const WorkerRegisterPage({super.key});

  @override
  State<WorkerRegisterPage> createState() => _WorkerRegisterPageState();
}

class _WorkerRegisterPageState extends State<WorkerRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _chineseNameController = TextEditingController();
  final _englishNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hkidController = TextEditingController();
  final _safetyCardController = TextEditingController();
  final _workerCertController = TextEditingController();
  final _api = ApiService();

  bool _loading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _chineseNameController.dispose();
    _englishNameController.dispose();
    _phoneController.dispose();
    _hkidController.dispose();
    _safetyCardController.dispose();
    _workerCertController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _api.getWorkerProfile();
      setState(() {
        _profileData = data;
        _chineseNameController.text = data['chineseName'] ?? '';
        _englishNameController.text = data['englishName'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _hkidController.text = data['hkId'] ?? '';
        _safetyCardController.text = data['safetyCard'] ?? '';
        _workerCertController.text = data['workerRegistrationNum'] ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入資料失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.updateWorkerProfile({
        'chineseName': _chineseNameController.text.trim(),
        'englishName': _englishNameController.text.trim(),
        'hkId': _hkidController.text.trim(),
        'safetyCard': _safetyCardController.text.trim(),
        'workerRegistrationNum': _workerCertController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('資料已保存'), backgroundColor: AppTheme.successColor),
      );
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('個人資料')),
      body: _profileData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 個人資料 Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('個人資料', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _chineseNameController,
                            decoration: const InputDecoration(labelText: '中文姓名 *', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.isEmpty ? '請輸入中文姓名' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _englishNameController,
                            decoration: const InputDecoration(labelText: '英文姓名 *', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.isEmpty ? '請輸入英文姓名' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: '手機號碼',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Color(0xFFF5F5F5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _hkidController,
                            decoration: const InputDecoration(
                              labelText: '香港身份證 (HKID)', border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 每日薪酬（只读）
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 100,
                                  child: Text('每日薪酬', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                                ),
                                Text(
                                  _profileData?['dailyWage'] != null
                                      ? 'HK\$ ${_profileData!['dailyWage']}'
                                      : '未設置',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 證書資料 Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('證書資料', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _safetyCardController,
                            decoration: const InputDecoration(
                              labelText: '平安卡 (綠卡)', hintText: '平安卡編號', border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _workerCertController,
                            decoration: const InputDecoration(
                              labelText: '工人註冊證 (可選)', hintText: '建造業工人註冊證編號', border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('保存資料', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
