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
  String? _error;
  String? _contractAttachmentName; // 选中的文件名
  Uint8List? _contractAttachmentBytes; // 文件内容（Web 下用 bytes）

  @override
  void initState() {
    super.initState();
    _selectedSiteId = widget.siteId; // 如果提供了 siteId，则预选
    _loadData();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _dailyWageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getWorkerHome(),
        _api.getContractorCompanies(),
      ]);
      if (!mounted) return;
      setState(() {
        final homeData = results[0] as Map<String, dynamic>;
        _sites = homeData['availableSites'] as List? ?? [];
        _companies = results[1] as List;
        _sitesLoading = false;
        _companiesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _sitesLoading = false; _companiesLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickContractFile() async {
    try {
      print('[DEBUG] Opening file picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // 改用 any，然后手动检查扩展名
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('[DEBUG] File selected: ${file.name}, size: ${file.bytes?.length}');
        
        // 检查文件扩展名
        final ext = file.name.split('.').last.toLowerCase();
        if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
          _showMsg('只支持 PDF、JPG、PNG 格式的文件');
          return;
        }
        
        setState(() {
          _contractAttachmentName = file.name;
          _contractAttachmentBytes = file.bytes;
        });
        print('[DEBUG] File loaded successfully');
      } else {
        print('[DEBUG] File selection cancelled');
      }
    } catch (e, stackTrace) {
      print('[ERROR] File picker error: $e');
      print('[ERROR] Stack trace: $stackTrace');
      if (mounted) {
        _showMsg('文件选择失败: $e');
      }
    }
  }

  /// 上传附件到服务器，返回服务器路径
  Future<String> _uploadAttachment() async {
    if (_contractAttachmentBytes == null || _contractAttachmentName == null) {
      throw Exception('請上傳僱傭合約附件');
    }
    return await _api.uploadFile(
      bytes: _contractAttachmentBytes!,
      filename: _contractAttachmentName!,
      folder: 'contracts',
    );
  }

  Future<void> _submit() async {
    // 必填验证
    if (_selectedSiteId == null) { _showMsg('請選擇地盤'); return; }
    if (_selectedCompanyId == null) { _showMsg('請選擇所屬判頭公司'); return; }
    if (_dailyWageController.text.trim().isEmpty) { _showMsg('請填寫每日薪酬'); return; }
    final dailyWage = double.tryParse(_dailyWageController.text.trim());
    if (dailyWage == null || dailyWage <= 0) { _showMsg('請填寫有效的每日薪酬'); return; }
    if (_contractAttachmentBytes == null) { _showMsg('請上傳僱傭合約附件'); return; }

    setState(() => _loading = true);
    try {
      final contractAttachment = await _uploadAttachment();
      await _api.applySite(
        siteId: _selectedSiteId!,
        companyId: _selectedCompanyId!,
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

        // 地盘选择（弹出单选）
        const Text('選擇地盤 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildSiteSelector(),
        const SizedBox(height: 20),

        // 判头公司选择（弹出单选）
        const Text('所屬判頭公司 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildCompanySelector(),
        const SizedBox(height: 20),

        // 每日薪酬
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

        // 雇佣合同上传
        const Text('僱傭合約附件 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildFileUpload(),
        const SizedBox(height: 20),

        // 申请说明
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

        // 提交按钮
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_loading || _selectedSiteId == null || _selectedCompanyId == null) ? null : _submit,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('提交申請', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  /// 地盘选择触发卡片
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
                        Text(
                          selectedSite['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                        if (selectedSite['address'] != null)
                          Text(
                            selectedSite['address'],
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                      ],
                    )
                  : Text(
                      _sites.isEmpty ? '暫無可申請的地盤' : '請選擇地盤',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 15),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// 弹出地盘选择 BottomSheet
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
                // 顶部标题栏
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
                // 列表
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
                            color: selected
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : AppTheme.backgroundColor,
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
                        subtitle: site['address'] != null
                            ? Text(site['address'], style: const TextStyle(fontSize: 13))
                            : null,
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                            : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                        onTap: () {
                          setState(() => _selectedSiteId = site['id'] as int);
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

  /// 判头公司选择触发卡片
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
                  ? Text(
                      selectedCompany['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                    )
                  : Text(
                      _companies.isEmpty ? '暫無判頭公司' : '請選擇判頭公司',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 15),
                    ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// 弹出判头公司选择 BottomSheet
  void _showCompanyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
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
                      const Text('選擇判頭公司', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      final c = _companies[i];
                      final selected = _selectedCompanyId == c['id'];
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.business,
                            color: selected ? AppTheme.primaryColor : AppTheme.textHint,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          c['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected ? AppTheme.primaryColor : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                            : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                        onTap: () {
                          setState(() => _selectedCompanyId = c['id'] as int);
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
                _contractAttachmentName ?? '點擊上傳僱傭合約（PDF/JPG/PNG）',
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
}
