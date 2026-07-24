import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 掃碼扣分頁面
/// 流程：掃描 QR → 解析工人編號 → 查 API → 顯示扣分界面
/// 扣分方式：選擇分類 → 選擇扣分項目（固定分值）→ 填寫備註 → 確認
class ScanDeductPage extends StatefulWidget {
  const ScanDeductPage({super.key});

  @override
  State<ScanDeductPage> createState() => _ScanDeductPageState();
}

class _ScanDeductPageState extends State<ScanDeductPage> {
  MobileScannerController? _cameraController;
  bool _scanned = false;
  bool _loading = false;
  String? _error;

  // 工人資訊
  Map<String, dynamic>? _worker;

  // 扣分項目數據
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  List<Map<String, dynamic>> _currentItems = [];
  Map<String, dynamic>? _selectedItem;

  // 備註
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _onScan(BarcodeCapture capture) {
    if (_scanned || _loading) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final workerNumber = barcode.rawValue!.trim();
    if (workerNumber.isEmpty) return;

    setState(() {
      _scanned = true;
      _loading = true;
      _error = null;
    });

    _lookupWorker(workerNumber);
  }

  Future<void> _lookupWorker(String workerNumber) async {
    try {
      final results = await Future.wait([
        ApiService().getWorkerByNumber(workerNumber),
        ApiService().getDeductionItems(),
      ]);
      if (!mounted) return;
      final worker = results[0] as Map<String, dynamic>;
      final categories = results[1] as List<Map<String, dynamic>>;
      setState(() {
        _worker = worker;
        _categories = categories;
        _selectedCategory = null;
        _currentItems = [];
        _selectedItem = null;
        _remarkController.clear();
        _loading = false;
      });
      _cameraController?.stop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
        _scanned = false;
      });
    }
  }

  void _rescan() {
    setState(() {
      _scanned = false;
      _error = null;
      _worker = null;
      _categories = [];
      _selectedCategory = null;
      _currentItems = [];
      _selectedItem = null;
    });
    _cameraController?.start();
  }

  void _onCategorySelected(String? categoryName) {
    if (categoryName == null) return;
    final cat = _categories.firstWhere((c) => c['categoryName'] == categoryName);
    setState(() {
      _selectedCategory = categoryName;
      _currentItems = (cat['items'] as List).cast<Map<String, dynamic>>();
      _selectedItem = null;
    });
  }

  void _onItemSelected(Map<String, dynamic> item) {
    setState(() => _selectedItem = item);
  }

  Future<void> _submitDeduct() async {
    if (_worker == null || _selectedItem == null) return;

    final points = _selectedItem!['points'] as int;
    final currentScore = (_worker!['siteSafetyScore'] as int?) ?? 15;
    final newScore = currentScore - points;

    final itemName = _selectedItem!['itemName'] as String;
    final remark = _remarkController.text.trim();
    final reason = '$_selectedCategory - $itemName${remark.isNotEmpty ? '（備註：$remark）' : ''}';

    if (newScore <= 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ 扣分後安全分為 0'),
          content: Text('扣分後安全分將降至 $newScore 分，系統將自動鎖卡及加入黑名單。\n\n分類：$_selectedCategory\n項目：$itemName\n扣分：$points 分\n\n確認繼續？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              child: const Text('確認扣分', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService().deductWorkerScore(
        _worker!['id'] as int, points, reason,
        siteId: _worker!['siteId'] as int?,
      );
      if (!mounted) return;
      setState(() => _loading = false);

      final remainingScore = result['siteSafetyScore'] ?? newScore;
      final autoLocked = result['autoLocked'] == true;
      final autoBlacklisted = result['autoBlacklisted'] == true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            remainingScore == 0 ? Icons.warning_amber_rounded : Icons.check_circle,
            color: remainingScore == 0 ? AppTheme.warningColor : AppTheme.successColor,
            size: 48,
          ),
          title: Text(remainingScore == 0 ? '扣分完成 — 已鎖卡 & 黑名單' : '扣分完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('工人：${_worker!['chineseName'] ?? '-'}'),
              Text('扣分：$points 分'),
              Text('分類：$_selectedCategory'),
              Text('項目：$itemName'),
              Text('剩餘安全分：$remainingScore 分'),
              if (autoLocked) const SizedBox(height: 8),
              if (autoLocked) const Text('🔒 已自動鎖卡', style: TextStyle(color: AppTheme.warningColor)),
              if (autoBlacklisted) const Text('🚫 已自動加入黑名單', style: TextStyle(color: AppTheme.errorColor)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _rescan(); },
              child: const Text('繼續掃描'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扣分失敗：${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃一掃 安全扣分'),
      ),
      body: _worker != null ? _buildDeductUI() : _buildScannerUI(),
    );
  }

  /// QR 掃描界面
  Widget _buildScannerUI() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _cameraController!,
                onDetect: _onScan,
              ),
              // 掃描框
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: _scanned ? AppTheme.successColor : AppTheme.primaryColor, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // 錯誤提示
              if (_error != null)
                Positioned(
                  bottom: 120,
                  left: 32,
                  right: 32,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              // Loading
              if (_loading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('將二維碼對準掃描框', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              const Text('支持掃描工人首頁或個人中心顯示的 QR Code', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
              if (_scanned) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _rescan,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新掃描'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 扣分界面
  Widget _buildDeductUI() {
    final siteSafetyScore = (_worker!['siteSafetyScore'] as int?) ?? 15;
    final siteSafetyTotal = (_worker!['siteSafetyTotal'] as int?) ?? 15;
    final deductPoints = _selectedItem != null ? (_selectedItem!['points'] as int) : 0;
    final newScore = (siteSafetyScore - deductPoints).clamp(0, siteSafetyTotal);
    final isZero = _selectedItem != null && newScore <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工人資訊卡
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('工人資訊', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow('工人編號', _worker!['workerNumber'] ?? '-'),
                  _buildInfoRow('工人姓名', _worker!['chineseName'] ?? '-'),
                  _buildInfoRow('所在地盤', _worker!['siteName'] ?? '暫無'),
                  _buildInfoRow('所屬公司', _worker!['companyName'] ?? '暫無'),
                  _buildInfoRow('現有安全分', '$siteSafetyScore / $siteSafetyTotal 分'),
                  if (_worker!['cardLocked'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: AppTheme.warningColor, size: 16),
                          SizedBox(width: 4),
                          Text('已鎖卡', style: TextStyle(color: AppTheme.warningColor)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 扣分項目選擇卡
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('安全扣分', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),

                  // 分類下拉
                  const Text('扣分類別', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: '請選擇扣分類別',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _categories.map((cat) => DropdownMenuItem(
                      value: cat['categoryName'] as String,
                      child: Text(cat['categoryName'] as String),
                    )).toList(),
                    onChanged: _onCategorySelected,
                  ),
                  const SizedBox(height: 16),

                  // 項目列表
                  if (_currentItems.isNotEmpty) ...[
                    const Text('扣分項目', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ..._currentItems.map((item) {
                      final itemName = item['itemName'] as String;
                      final points = item['points'] as int;
                      final isSelected = _selectedItem?['id'] == item['id'];
                      return Card(
                        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _onItemSelected(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '扣 $points 分',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  // 備註
                  if (_selectedItem != null) ...[
                    const SizedBox(height: 16),
                    const Text('備註（選填）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _remarkController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: '可填寫備註說明',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 剩餘安全分預覽（選中項目後顯示）
          if (_selectedItem != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isZero ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isZero ? AppTheme.errorColor : AppTheme.successColor),
              ),
              child: Column(
                children: [
                  Text(
                    '剩餘安全分',
                    style: TextStyle(fontSize: 14, color: isZero ? AppTheme.errorColor : AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$newScore / $siteSafetyTotal',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isZero ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                  ),
                  if (isZero) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '扣分後安全分為 0，將自動鎖卡及加入黑名單',
                      style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),

          // 確認按鈕
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading || _selectedItem == null ? null : _submitDeduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: isZero ? AppTheme.errorColor : AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isZero ? '確認扣分（將鎖卡 & 黑名單）' : '確認扣分',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // 返回重新掃描
          Center(
            child: TextButton.icon(
              onPressed: _rescan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('返回掃描'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
