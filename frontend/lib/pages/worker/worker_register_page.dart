import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:file_picker/file_picker.dart';

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
  final _safetyCardController = TextEditingController();
  final _workerCertController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _api = ApiService();

  bool _loading = false;
  Map<String, dynamic>? _profileData;

  // 上传附件状态
  String? _safetyCardAttachmentUrl;
  String? _safetyCardAttachmentName;
  String? _workerRegCertAttachmentUrl;
  String? _workerRegCertAttachmentName;

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
    _safetyCardController.dispose();
    _workerCertController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
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
        _safetyCardController.text = data['safetyCard'] ?? '';
        _workerCertController.text = data['workerRegistrationNum'] ?? '';
        _safetyCardAttachmentUrl = data['safetyCardAttachment'];
        _safetyCardAttachmentName = _safetyCardAttachmentUrl != null ? '已上傳' : null;
        _workerRegCertAttachmentUrl = data['workerRegCertAttachment'];
        _workerRegCertAttachmentName = _workerRegCertAttachmentUrl != null ? '已上傳' : null;
        _emergencyContactNameController.text = data['emergencyContactName'] ?? '';
        _emergencyContactPhoneController.text = data['emergencyContactPhone'] ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入資料失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _pickAndUpload(bool isSafetyCard) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _loading = true);

      final url = await _api.uploadFile(
        bytes: file.bytes!,
        filename: file.name,
        folder: 'certificates',
      );

      setState(() {
        if (isSafetyCard) {
          _safetyCardAttachmentUrl = url;
          _safetyCardAttachmentName = file.name;
        } else {
          _workerRegCertAttachmentUrl = url;
          _workerRegCertAttachmentName = file.name;
        }
        _loading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${file.name} 上傳成功'), backgroundColor: AppTheme.successColor),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 前端驗證：證書 4 項必填
    final safetyCard = _safetyCardController.text.trim();
    final workerRegNum = _workerCertController.text.trim();
    if (safetyCard.isEmpty ||
        _safetyCardAttachmentUrl == null || _safetyCardAttachmentUrl!.isEmpty ||
        workerRegNum.isEmpty ||
        _workerRegCertAttachmentUrl == null || _workerRegCertAttachmentUrl!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請完善平安卡及工人註冊證資料（編號+附件需全部填寫）'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.updateWorkerProfile({
        'chineseName': _chineseNameController.text.trim(),
        'englishName': _englishNameController.text.trim(),
        'safetyCard': safetyCard,
        'safetyCardAttachment': _safetyCardAttachmentUrl,
        'workerRegistrationNum': workerRegNum,
        'workerRegCertAttachment': _workerRegCertAttachmentUrl,
        'emergencyContactName': _emergencyContactNameController.text.trim(),
        'emergencyContactPhone': _emergencyContactPhoneController.text.trim(),
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
                          const SizedBox(height: 12),
                          // 出生日期（只读）
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
                                  child: Text('出生日期', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                                ),
                                Text(
                                  _profileData?['birthDate'] != null
                                      ? '${_profileData!['birthDate']}'
                                      : '未設置',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emergencyContactNameController,
                            decoration: const InputDecoration(
                              labelText: '緊急聯絡人（姓名）',
                              hintText: '非必填',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emergencyContactPhoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: '緊急聯絡人電話',
                              hintText: '非必填',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v != null && v.isNotEmpty && !RegExp(r'^\d+$').hasMatch(v)) {
                                return '電話號碼只能包含數字';
                              }
                              return null;
                            },
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
                          // 平安卡編號
                          TextFormField(
                            controller: _safetyCardController,
                            decoration: const InputDecoration(
                              labelText: '平安卡 (綠卡) *', hintText: '強制性基本安全訓練課程 (平安卡)編號', border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 平安卡附件上傳
                          _buildUploadRow(
                            label: '平安卡附件 *',
                            fileName: _safetyCardAttachmentName,
                            onTap: () => _pickAndUpload(true),
                            uploaded: _safetyCardAttachmentUrl != null && _safetyCardAttachmentUrl!.isNotEmpty,
                          ),
                          const SizedBox(height: 16),
                          // 工人註冊證編號
                          TextFormField(
                            controller: _workerCertController,
                            decoration: const InputDecoration(
                              labelText: '建造業工人註冊證 *', hintText: '建造業工人註冊證編號', border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 註冊證附件上傳
                          _buildUploadRow(
                            label: '註冊證附件 *',
                            fileName: _workerRegCertAttachmentName,
                            onTap: () => _pickAndUpload(false),
                            uploaded: _workerRegCertAttachmentUrl != null && _workerRegCertAttachmentUrl!.isNotEmpty,
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

  Widget _buildUploadRow({
    required String label,
    String? fileName,
    required VoidCallback onTap,
    required bool uploaded,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: uploaded ? AppTheme.successColor : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fileName ?? label,
              style: TextStyle(
                fontSize: 14,
                color: uploaded ? AppTheme.successColor : AppTheme.textHint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            uploaded ? Icons.check_circle : Icons.upload_file,
            color: uploaded ? AppTheme.successColor : AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onTap,
            child: Text(
              uploaded ? '重新上傳' : '上傳',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
