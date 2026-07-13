import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class ChangeSitePage extends StatefulWidget {
  const ChangeSitePage({super.key});

  @override
  State<ChangeSitePage> createState() => _ChangeSitePageState();
}

class _ChangeSitePageState extends State<ChangeSitePage> {
  final _api = ApiService();
  final _reasonController = TextEditingController();
  final _dailyWageController = TextEditingController();

  bool _loading = false;
  bool _sitesLoading = true;
  List<dynamic> _sites = [];
  int? _selectedSiteId;
  String? _error;
  String? _contractAttachmentName;
  Uint8List? _contractAttachmentBytes;

  // 历史记录
  List<dynamic> _history = [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadHistory();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _dailyWageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await _api.getWorkerHome();
      if (!mounted) return;
      setState(() {
        _sites = data['availableSites'] as List? ?? [];
        _sitesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _sitesLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final data = await _api.getChangeHistory();
      if (!mounted) return;
      setState(() {
        _history = data['content'] as List? ?? [];
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
      final msg = e.toString().replaceAll("Exception: ", "");
      if (msg != 'NO_RECORD' && !msg.contains('無記錄')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.warningColor),
        );
      }
    }
  }

  Future<void> _pickContractFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        setState(() {
          _contractAttachmentName = file.name;
          _contractAttachmentBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted) _showMsg('文件选择失败: $e');
    }
  }

  Future<String> _uploadAttachment() async {
    if (_contractAttachmentBytes == null || _contractAttachmentName == null) {
      throw Exception('请上传僱佣合约附件');
    }
    return await _api.uploadFile(
      bytes: _contractAttachmentBytes!,
      filename: _contractAttachmentName!,
      folder: 'contracts',
    );
  }

  Future<void> _submit() async {
    if (_selectedSiteId == null) { _showMsg('请选择目标地盘'); return; }
    if (_dailyWageController.text.trim().isEmpty) { _showMsg('请填写每日薪酬'); return; }
    final dailyWage = double.tryParse(_dailyWageController.text.trim());
    if (dailyWage == null || dailyWage <= 0) { _showMsg('请填写有效的每日薪酬'); return; }
    if (_contractAttachmentBytes == null) { _showMsg('请上传僱佣合约附件'); return; }

    setState(() => _loading = true);
    try {
      final contractAttachment = await _uploadAttachment();
      await _api.changeSite(
        targetSiteId: _selectedSiteId!,
        reason: _reasonController.text.trim(),
        dailyWage: _dailyWageController.text.trim(),
        contractAttachment: contractAttachment,
      );
      if (!mounted) return;
      _showMsg('更換地盤申請已提交，等待審核', isError: false);
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

  Future<void> _cancelRequest() async {
    try {
      await _api.cancelChangeSite();
      if (!mounted) return;
      _showMsg('申請已取消', isError: false);
      _loadHistory();
    } catch (e) {
      if (!mounted) return;
      _showMsg(e.toString());
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

  @override
  Widget build(BuildContext context) {
    final hasPending = _history.any((r) => r['status'] == 'PENDING');
    return Scaffold(
      appBar: AppBar(title: const Text('更换地盘')),
      body: _sitesLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 当前地盘信息
                _buildCurrentSiteCard(),
                const SizedBox(height: 24),

                // 申請表單（無待審核時才顯示）
                if (!hasPending) ...[
                  Text('選擇目標地盤 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildSiteSelector(),
                  const SizedBox(height: 20),

                  const Text('每日薪酬（HKD）*', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dailyWageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '請填寫每日薪酬',
                      prefixText: 'HK\$ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('僱傭合約附件 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildFileUpload(),
                  const SizedBox(height: 20),

                  const Text('更换原因', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: '可填寫備註信息...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_loading || _selectedSiteId == null) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('提交更換申請', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else ...[
                  // 有待审核申请
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.hourglass_empty, color: AppTheme.warningColor, size: 40),
                        const SizedBox(height: 12),
                        const Text('您有一個待審核的更換申請', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          '更换至：${_history.firstWhere((r) => r['status'] == 'PENDING')['toSiteName'] ?? ''}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _cancelRequest,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(color: AppTheme.errorColor),
                          ),
                          child: const Text('撤銷申請'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Text('历史更换记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildHistoryList(),
              ],
            ),
    );
  }

  Widget _buildCurrentSiteCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _api.getCurrentSite(),
      builder: (context, snapshot) {
        final site = snapshot.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('当前地盘', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    Text(
                      site?['name'] ?? '暂无地盘',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSiteSelector() {
    final selectedSite = _sites.firstWhere(
      (s) => s['id'] == _selectedSiteId,
      orElse: () => null,
    );
    return InkWell(
      onTap: _sites.isEmpty ? null : () => _showSitePicker(),
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
              Icons.location_city,
              color: selectedSite != null ? AppTheme.primaryColor : AppTheme.textHint,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selectedSite != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selectedSite['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        if (selectedSite['address'] != null)
                          Text(selectedSite['address'], style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    )
                  : Text(
                      _sites.isEmpty ? '暫無可用地盤' : '請選擇地盤',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 15),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showSitePicker() {
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
                      const Text('選擇地盤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    itemCount: _sites.length,
                    itemBuilder: (_, i) {
                      final site = _sites[i];
                      final selected = _selectedSiteId == site['id'];
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_city,
                            color: selected ? AppTheme.primaryColor : AppTheme.textHint,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          site['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: site['address'] != null ? Text(site['address'], style: const TextStyle(fontSize: 13)) : null,
                        trailing: selected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                        onTap: () {
                          setState(() => _selectedSiteId = site['id']);
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

  Widget _buildFileUpload() {
    return InkWell(
      onTap: _pickContractFile,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _contractAttachmentName != null ? Icons.check_circle : Icons.upload_file,
              color: _contractAttachmentName != null ? Colors.green : AppTheme.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _contractAttachmentName ?? '点击上传僱佣合约（PDF/JPG/PNG）',
                style: TextStyle(
                  color: _contractAttachmentName != null ? AppTheme.textPrimary : AppTheme.textHint,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('暫無歷史記錄', style: TextStyle(color: AppTheme.textHint, fontSize: 14)),
        ),
      );
    }
    return Column(
      children: _history.map((r) {
        final status = r['status'] ?? '';
        final approved = status == 'APPROVED';
        final rejected = status == 'REJECTED';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              approved ? Icons.check_circle : rejected ? Icons.cancel : Icons.hourglass_empty,
              color: approved ? AppTheme.successColor : rejected ? AppTheme.errorColor : AppTheme.warningColor,
            ),
            title: Text('更换至 ${r['toSiteName'] ?? ''}'),
            subtitle: Text(r['requestedAt']?.toString().split('T')[0] ?? ''),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: approved
                    ? AppTheme.successColor.withOpacity(0.1)
                    : rejected
                        ? AppTheme.errorColor.withOpacity(0.1)
                        : AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                approved ? '通过' : rejected ? '拒绝' : '待审核',
                style: TextStyle(
                  fontSize: 12,
                  color: approved ? AppTheme.successColor : rejected ? AppTheme.errorColor : AppTheme.warningColor,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
