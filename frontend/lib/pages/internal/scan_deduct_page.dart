import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 掃碼扣分頁面
/// 流程：掃描 QR → 解析工人編號 → 查 API → 顯示扣分界面
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

  // 扣分輸入
  final _deductController = TextEditingController();
  final _reasonController = TextEditingController();
  int _deductPoints = 1;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _deductController.dispose();
    _reasonController.dispose();
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
      final worker = await ApiService().getWorkerByNumber(workerNumber);
      if (!mounted) return;
      setState(() {
        _worker = worker;
        _loading = false;
        _deductPoints = 1;
        _deductController.text = '1';
        _reasonController.clear();
      });
      _cameraController?.stop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
        _scanned = false; // 允許重新掃描
      });
    }
  }

  void _rescan() {
    setState(() {
      _scanned = false;
      _error = null;
      _worker = null;
    });
    _cameraController?.start();
  }

  void _setDeductPoints(int points) {
    final maxDeduct = (_worker!['siteSafetyScore'] as int?) ?? 15;
    setState(() {
      _deductPoints = points.clamp(1, maxDeduct);
      _deductController.text = _deductPoints.toString();
    });
  }

  void _onDeductInputChanged(String value) {
    final parsed = int.tryParse(value);
    final maxDeduct = (_worker!['siteSafetyScore'] as int?) ?? 15;
    if (parsed != null) {
      _deductPoints = parsed.clamp(1, maxDeduct);
      _deductController.text = _deductPoints.toString();
      _deductController.selection = TextSelection.fromPosition(
        TextPosition(offset: _deductController.text.length),
      );
    } else if (value.isEmpty) {
      _deductPoints = 0;
    }
  }

  Future<void> _submitDeduct() async {
    if (_worker == null || _deductPoints <= 0) return;

    final currentScore = (_worker!['siteSafetyScore'] as int?) ?? 15;
    final newScore = currentScore - _deductPoints;
    final reason = _reasonController.text.trim().isEmpty ? '安全違規扣分' : _reasonController.text.trim();

    // 確認對話框
    if (newScore <= 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ 扣分後安全分為 0'),
          content: Text('扣分後安全分將降至 $newScore 分，系統將自動鎖卡及加入黑名單。\n\n扣分：$_deductPoints 分\n原因：$reason\n\n確認繼續？'),
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
        _worker!['id'] as int,
        _deductPoints,
        reason,
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
              Text('扣分：$_deductPoints 分'),
              Text('剩餘安全分：$remainingScore 分'),
              if (autoLocked) const SizedBox(height: 8),
              if (autoLocked) const Text('🔒 已自動鎖卡', style: TextStyle(color: AppTheme.warningColor)),
              if (autoBlacklisted) const Text('🚫 已自動加入黑名單', style: TextStyle(color: AppTheme.errorColor)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // 關閉結果
                _rescan();          // 返回掃描
              },
              child: const Text('繼續掃描'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('扣分失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.errorColor,
        ),
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
    final newScore = (siteSafetyScore - _deductPoints).clamp(0, siteSafetyTotal);
    final isZero = newScore <= 0;
    final maxDeduct = siteSafetyScore;

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

          // 扣分輸入卡
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('安全扣分', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),

                  // 數字輸入 + 細小上下箭頭
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('扣分數量：', style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      // 輸入框 + 上下箭頭
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _deductController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.only(left: 8, right: 4, top: 8, bottom: 8),
                            suffixIcon: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _deductPoints < maxDeduct
                                      ? () => _setDeductPoints(_deductPoints + 1)
                                      : null,
                                  child: Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 16,
                                    color: _deductPoints < maxDeduct
                                        ? AppTheme.primaryColor
                                        : AppTheme.textHint,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _deductPoints > 1
                                      ? () => _setDeductPoints(_deductPoints - 1)
                                      : null,
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: _deductPoints > 1
                                        ? AppTheme.primaryColor
                                        : AppTheme.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onChanged: _onDeductInputChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('每次最多扣 $maxDeduct 分', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  const SizedBox(height: 16),

                  // 扣分原因
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '扣分原因',
                      hintText: '請輸入扣分原因',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 剩餘安全分
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
              onPressed: _loading || _deductPoints <= 0 ? null : _submitDeduct,
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
