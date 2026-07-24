import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

class SiteApplyPage extends StatefulWidget {
  final int? siteId;
  final String? siteName;
  final VoidCallback? onApplied;

  const SiteApplyPage({super.key, this.siteId, this.siteName, this.onApplied});

  @override
  State<SiteApplyPage> createState() => _SiteApplyPageState();
}

class _SiteApplyPageState extends State<SiteApplyPage> {
  final _api = ApiService();
  final _remarkController = TextEditingController();
  final _dailyWageController = TextEditingController();

  bool _loading = false;
  bool _sitesLoading = true;
  bool _companiesLoading = true;
  List<dynamic> _sites = [];
  List<dynamic> _companies = [];
  int? _selectedSiteId;
  int? _selectedCompanyId;
  int? _currentCompanyId; // 工人当前公司（已加入地盘时自动填充）
  String? _currentCompanyName;
  String? _error;
  String? _contractAttachmentName;
  Uint8List? _contractAttachmentBytes;

  // 證書資料
  final _safetyCardController = TextEditingController();
  final _workerRegCertController = TextEditingController();
  String? _safetyCardAttachmentUrl;
  String? _safetyCardAttachmentName;
  String? _workerRegCertAttachmentUrl;
  String? _workerRegCertAttachmentName;
  bool _certsComplete = false;

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId;
    _loadData();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _dailyWageController.dispose();
    _safetyCardController.dispose();
    _workerRegCertController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getWorkerHome(),
        _api.getContractorCompanies(),
        _api.getWorkerProfile(),
      ]);
      if (!mounted) return;
      final homeData = results[0] as Map<String, dynamic>;
      final profileData = results[2] as Map<String, dynamic>;

      final safetyCard = profileData['safetyCard'] as String? ?? '';
      final safetyCardAtt = profileData['safetyCardAttachment'] as String? ?? '';
      final regNum = profileData['workerRegistrationNum'] as String? ?? '';
      final regAtt = profileData['workerRegCertAttachment'] as String? ?? '';

      setState(() {
        _sites = homeData['availableSites'] as List? ?? [];
        _companies = results[1] as List;

        // 获取当前公司信息（兼容新旧字段名）
        final profile = homeData['profile'] as Map<String, dynamic>?;
        if (profile != null) {
          final companyId = (profile['companyId'] ?? profile['currentCompanyId']) as int?;
          final companyName = (profile['companyName'] ?? profile['currentCompanyName']) as String?;
          if (companyId != null && companyName != null && companyName.isNotEmpty) {
            _currentCompanyId = companyId;
            _currentCompanyName = companyName;
          } else if (companyId != null) {
            // 有 companyId 但无 companyName，从公司列表中查找
            _currentCompanyId = companyId;
            _currentCompanyName = null; // 稍后从 company 列表中匹配
          }
        }

        _sitesLoading = false;
        _companiesLoading = false;

        // 如果有 companyId 但无 companyName，从公司列表中匹配
        if (_currentCompanyId != null && _currentCompanyName == null) {
          final matched = _companies.firstWhere(
            (c) => c['id'] == _currentCompanyId,
            orElse: () => null,
          );
          if (matched != null) {
            _currentCompanyName = matched['name'] as String?;
          }
        }

        _safetyCardController.text = safetyCard;
        _safetyCardAttachmentUrl = safetyCardAtt.isNotEmpty ? safetyCardAtt : null;
        _safetyCardAttachmentName = safetyCardAtt.isNotEmpty ? '已上傳' : null;
        _workerRegCertController.text = regNum;
        _workerRegCertAttachmentUrl = regAtt.isNotEmpty ? regAtt : null;
        _workerRegCertAttachmentName = regAtt.isNotEmpty ? '已上傳' : null;

        _certsComplete = safetyCard.isNotEmpty && safetyCardAtt.isNotEmpty
            && regNum.isNotEmpty && regAtt.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _sitesLoading = false; _companiesLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickAndUploadCert(bool isSafetyCard) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.size > 5 * 1024 * 1024) {
        _showMsg('文件大小不能超過5MB');
        return;
      }

      setState(() => _loading = true);
      final url = await _api.uploadFile(
        bytes: file.bytes!, filename: file.name, folder: 'certificates',
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
      _showMsg('${file.name} 上傳成功', isError: false);
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      _showMsg('上傳失敗：$e');
    }
  }

  /// 保存證書資料到後端
  Future<bool> _saveCertificates() async {
    final safetyCard = _safetyCardController.text.trim();
    final regNum = _workerRegCertController.text.trim();
    if (safetyCard.isEmpty || _safetyCardAttachmentUrl == null || _safetyCardAttachmentUrl!.isEmpty
        || regNum.isEmpty || _workerRegCertAttachmentUrl == null || _workerRegCertAttachmentUrl!.isEmpty) {
      _showMsg('請完善平安卡及工人註冊證資料（編號+附件需全部填寫）');
      return false;
    }
    try {
      await _api.updateWorkerProfile({
        'safetyCard': safetyCard,
        'safetyCardAttachment': _safetyCardAttachmentUrl,
        'workerRegistrationNum': regNum,
        'workerRegCertAttachment': _workerRegCertAttachmentUrl,
      });
      setState(() => _certsComplete = true);
      return true;
    } catch (e) {
      _showMsg('證書保存失敗：$e');
      return false;
    }
  }

  Future<void> _submit() async {
    // 先確保證書資料完整
    if (!_certsComplete) {
      final saved = await _saveCertificates();
      if (!saved) return;
    }

    if (_selectedSiteId == null) { _showMsg('請選擇地盤'); return; }
    // companyId 从 profile 获取（自动填充当前公司）
    final companyId = _selectedCompanyId ?? _currentCompanyId;
    if (companyId == null) { _showMsg('請選擇所屬判頭公司'); return; }
    if (_dailyWageController.text.trim().isEmpty) { _showMsg('請填寫每日薪酬'); return; }
    final dailyWage = double.tryParse(_dailyWageController.text.trim());
    if (dailyWage == null || dailyWage <= 0) { _showMsg('請填寫有效的每日薪酬'); return; }
    if (_contractAttachmentBytes == null) { _showMsg('請上傳僱傭合約附件'); return; }

    setState(() => _loading = true);
    try {
      final contractAttachment = await _uploadAttachment();
      await _api.applySite(
        siteId: _selectedSiteId!,
        companyId: companyId!,
        dailyWage: _dailyWageController.text.trim(),
        contractAttachment: contractAttachment,
        remark: _remarkController.text.trim(),
      );
      if (!mounted) return;
      _showMsg('申請已提交，請等待判頭審核', isError: false);
      widget.onApplied?.call();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showMsg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickContractFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.size > 5 * 1024 * 1024) {
          _showMsg('文件大小不能超過5MB');
          return;
        }
        setState(() {
          _contractAttachmentName = file.name;
          _contractAttachmentBytes = file.bytes;
        });
      }
    } catch (e) {
      _showMsg('文件選擇失敗：$e');
    }
  }

  Future<String> _uploadAttachment() async {
    if (_contractAttachmentBytes == null || _contractAttachmentName == null) {
      throw Exception('請上傳僱傭合約附件');
    }
    return await _api.uploadFile(
      bytes: _contractAttachmentBytes!, filename: _contractAttachmentName!, folder: 'contracts',
    );
  }

  void _showMsg(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorColor : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _sitesLoading || _companiesLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('申請加入地盤'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.errorColor)))
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 證書資料區域（未完善時顯示紅框提醒）
        if (!_certsComplete) ...[
          _buildCertSection(),
          const SizedBox(height: 24),
        ],

        // 提示
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outlined, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text('請選擇地盤、所屬判頭公司，填寫每日薪酬並上傳僱傭合約，提交後需由判頭審核通過。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('選擇地盤 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildSiteSelector(),
        const SizedBox(height: 20),

        const Text('所屬判頭公司 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_currentCompanyName != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Text(_currentCompanyName!, style: const TextStyle(fontSize: 15)),
                const Spacer(),
                Icon(Icons.lock, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('當前公司', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          )
        else
          _buildCompanySelector(),
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
        _buildFileUpload('僱傭合約', _contractAttachmentName, _pickContractFile),
        const SizedBox(height: 20),

        const Text('申請說明（選填）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _remarkController,
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
            onPressed: (_loading || _selectedSiteId == null || (_selectedCompanyId == null && _currentCompanyId == null)) ? null : _submit,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('提交申請', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  /// 證書資料區塊（強制填寫）
  Widget _buildCertSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: AppTheme.warningColor, size: 20),
              SizedBox(width: 8),
              Text('請先完善證書資料', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('申請加入地盤前，需填寫平安卡及工人註冊證資料',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),

          // 平安卡編號
          TextFormField(
            controller: _safetyCardController,
            decoration: const InputDecoration(
              labelText: '平安卡 (綠卡) 編號 *', border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _buildFileUpload('平安卡附件', _safetyCardAttachmentName, () => _pickAndUploadCert(true)),
          const SizedBox(height: 16),

          // 註冊證編號
          TextFormField(
            controller: _workerRegCertController,
            decoration: const InputDecoration(
              labelText: '工人註冊證編號 *', border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _buildFileUpload('註冊證附件', _workerRegCertAttachmentName, () => _pickAndUploadCert(false)),
        ],
      ),
    );
  }

  Widget _buildFileUpload(String label, String? fileName, VoidCallback onTap) {
    final uploaded = fileName != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: uploaded ? AppTheme.successColor : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              uploaded ? Icons.check_circle : Icons.upload_file,
              color: uploaded ? AppTheme.successColor : AppTheme.primaryColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                uploaded ? fileName! : '點擊上傳$label（PDF/JPG/PNG）',
                style: TextStyle(
                  fontSize: 13,
                  color: uploaded ? AppTheme.successColor : AppTheme.textHint,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────── 以下为原有选择器，保持不变 ──────────

  Widget _buildSiteSelector() { /* same as before */ return _buildSelector(
    icon: Icons.location_city,
    emptyText: '暫無可申請的地盤',
    hintText: '請選擇地盤',
    selected: _sites.firstWhere((s) => s['id'] == _selectedSiteId, orElse: () => null),
    items: _sites,
    selectedId: _selectedSiteId,
    onSelected: (id) => setState(() => _selectedSiteId = id),
    subtitleKey: 'address',
  );}

  Widget _buildCompanySelector() { return _buildSelector(
    icon: Icons.business,
    emptyText: '暫無判頭公司',
    hintText: '請選擇判頭公司',
    selected: _companies.firstWhere((c) => c['id'] == _selectedCompanyId, orElse: () => null),
    items: _companies,
    selectedId: _selectedCompanyId,
    onSelected: (id) => setState(() => _selectedCompanyId = id),
  );}

  Widget _buildSelector({
    required IconData icon,
    required String emptyText,
    required String hintText,
    required dynamic selected,
    required List<dynamic> items,
    required int? selectedId,
    required ValueChanged<int> onSelected,
    String? subtitleKey,
  }) {
    return InkWell(
      onTap: items.isEmpty ? null : () => _showPicker(items: items, selectedId: selectedId, onSelected: onSelected, title: hintText, subtitleKey: subtitleKey, icon: icon),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: selected != null ? AppTheme.primaryColor : AppTheme.textHint, size: 22),
          const SizedBox(width: 12),
          Expanded(child: selected != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(selected['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                if (subtitleKey != null && selected[subtitleKey] != null)
                  Text(selected[subtitleKey], style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ])
            : Text(items.isEmpty ? emptyText : hintText, style: TextStyle(color: AppTheme.textHint, fontSize: 15))),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  void _showPicker({required List<dynamic> items, required int? selectedId, required ValueChanged<int> onSelected, required String title, String? subtitleKey, IconData icon = Icons.location_city}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ]),
          ),
          Expanded(child: ListView.builder(
            controller: scrollCtrl, itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final sel = selectedId == item['id'];
              return ListTile(
                leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: sel ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.backgroundColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: sel ? AppTheme.primaryColor : AppTheme.textHint, size: 20)),
                title: Text(item['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, color: sel ? AppTheme.primaryColor : AppTheme.textPrimary)),
                subtitle: subtitleKey != null && item[subtitleKey] != null ? Text(item[subtitleKey], style: const TextStyle(fontSize: 13)) : null,
                trailing: sel ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                onTap: () { onSelected(item['id'] as int); Navigator.pop(ctx); },
              );
            },
          )),
        ]),
      ),
    );
  }
}
