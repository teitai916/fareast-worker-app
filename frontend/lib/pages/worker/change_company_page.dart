import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class ChangeCompanyPage extends StatefulWidget {
  const ChangeCompanyPage({super.key});

  @override
  State<ChangeCompanyPage> createState() => _ChangeCompanyPageState();
}

class _ChangeCompanyPageState extends State<ChangeCompanyPage> {
  final _api = ApiService();
  final _reasonController = TextEditingController();
  final _salaryController = TextEditingController(); // 每日薪酬

  bool _loading = false;
  bool _cancelling = false;
  bool _companiesLoading = true;
  List<dynamic> _companies = [];
  int? _selectedCompanyId;
  String? _error;
  String? _currentCompanyName; // 当前公司名称
  Map<String, dynamic>? _pendingChange; // 待处理的更换公司申请
  
  // 文件上传
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loadCurrentCompany();
    _loadCompanies();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentCompany() async {
    try {
      final data = await _api.getWorkerHome();
      if (!mounted) return;
      setState(() {
        _currentCompanyName = data?['profile']?['companyName'] ?? '未知公司';
        _pendingChange = data?['pendingCompanyChange'];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentCompanyName = '未知公司';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加載公司信息失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final data = await _api.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies = data;
        _companiesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _companiesLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) {
          _showMsg('文件大小不能超過5MB');
          return;
        }
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      _showMsg('選擇文件失敗：$e');
    }
  }

  Future<void> _submit() async {
    if (_selectedCompanyId == null) { _showMsg('請選擇目標公司'); return; }
    if (_salaryController.text.trim().isEmpty) { _showMsg('請填寫每日薪酬'); return; }

    setState(() => _loading = true);
    try {
      await _api.requestCompanyChange(
        toCompanyId: _selectedCompanyId!,
        reason: _reasonController.text.trim(),
        dailySalary: double.tryParse(_salaryController.text.trim()),
        contractFileBytes: _selectedFile?.bytes,
        contractFileName: _selectedFile?.name,
      );
      if (!mounted) return;
      _showMsg('更換公司申請已提交，等待審核', isError: false);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMsg(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorColor : Colors.green,
      ),
    );
  }

  /// 撤销待处理的更换公司申请
  Future<void> _cancelPendingChange() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認撤銷'),
        content: const Text('確定要撤銷當前的更換公司申請嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('確認撤銷'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling = true);
    try {
      await _api.cancelCompanyChange();
      if (!mounted) return;
      _showMsg('已撤銷更換公司申請', isError: false);
      setState(() {
        _pendingChange = null;
        _cancelling = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showMsg('撤銷失敗：$e');
      setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更換公司')),
      body: _companiesLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 当前公司信息
                _buildCurrentCompanyCard(),
                const SizedBox(height: 16),

                // 待处理申请卡片（如有）
                _buildPendingChangeCard(),

                // 有待处理申请时，不显示填写表单
                if (_pendingChange == null) ...[
                  // 目标公司选择
                  const SizedBox(height: 8),
                  const Text('選擇目標公司 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildCompanySelector(),
                  const SizedBox(height: 20),

                  // 每日薪酬
                  const Text('每日薪酬 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '請填寫每日薪酬',
                      suffixText: 'HKD',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 雇佣合约文件
                  const Text('僱傭合約文件附件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildFileUpload(),
                  const SizedBox(height: 20),

                  // 更换原因
                  const Text('更換原因', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: '可填寫備註資訊...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 提交按钮
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_loading || _selectedCompanyId == null) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('提交更換申請', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildCurrentCompanyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.business, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('當前公司', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text(
                  _currentCompanyName ?? '載入中...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 待处理更换公司申请卡片
  Widget _buildPendingChangeCard() {
    if (_pendingChange == null) return const SizedBox.shrink();
    final p = _pendingChange!;
    return Card(
      color: Colors.orange.shade50,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题 + 状态标签
            Row(
              children: [
                const Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('待審核的更換公司申請',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('審核中', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 目标公司
            _infoRow('目標公司', p['toCompanyName'] ?? '-'),
            const SizedBox(height: 6),
            // 原公司
            _infoRow('原公司', p['fromCompanyName'] ?? '-'),
            const SizedBox(height: 6),
            // 每日薪酬
            if (p['dailySalary'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _infoRow('每日薪酬', 'HK\$ ${p['dailySalary']}'),
              ),
            // 申请原因
            if ((p['reason'] ?? '').toString().isNotEmpty)
              _infoRow('申請原因', p['reason']),
            const SizedBox(height: 6),
            // 提交时间
            _infoRow('提交時間', _formatTime(p['requestedAt'])),
            const SizedBox(height: 16),
            // 撤销按钮
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _cancelling ? null : _cancelPendingChange,
                icon: _cancelling
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(_cancelling ? '撤銷中...' : '撤銷申請'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '-';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  Widget _buildCompanySelector() {
    final selectedCompany = _companies.firstWhere(
      (c) => c['id'] == _selectedCompanyId,
      orElse: () => null,
    );
    return InkWell(
      onTap: _companies.isEmpty ? null : () => _showCompanyPicker(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.business,
              color: selectedCompany != null ? AppTheme.primaryColor : AppTheme.textHint,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selectedCompany != null
                  ? Text(selectedCompany['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))
                  : Text(
                      _companies.isEmpty ? '暫無可用公司' : '請選擇公司',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 15),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildFileUpload() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _selectedFile != null ? Icons.check_circle : Icons.upload_file,
              color: _selectedFile != null ? AppTheme.successColor : AppTheme.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _selectedFile != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedFile!.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB', 
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    )
                  : Text('點擊上傳文件（PDF、JPG、PNG）', 
                      style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
            ),
            if (_selectedFile != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedFile = null),
              ),
          ],
        ),
      ),
    );
  }

  void _showCompanyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const Text('選擇公司', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _companies.length,
                    itemBuilder: (_, i) {
                      final company = _companies[i];
                      final selected = _selectedCompanyId == company['id'];
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.business,
                            color: selected ? AppTheme.primaryColor : AppTheme.textHint,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          company['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: selected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                        onTap: () {
                          setState(() => _selectedCompanyId = company['id']);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
