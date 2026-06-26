import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/pages/worker/safety_videos_page.dart';
import 'package:fareast_worker_app/pages/notifications_page.dart';
import 'package:fareast_worker_app/pages/internal/scan_deduct_page.dart';
import 'package:fareast_worker_app/widgets/weather_warning_bar.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class InternalHomePage extends StatefulWidget {
  const InternalHomePage({super.key});

  @override
  State<InternalHomePage> createState() => _InternalHomePageState();
}

class _InternalHomePageState extends State<InternalHomePage> {
  final _api = ApiService();
  int _currentIndex = 0;
  bool _loading = true;

  // 首页数据
  Map<String, dynamic>? _homeData;
  Map<String, dynamic>? _currentSite;
  Map<String, dynamic>? _attendanceData; // 当日考勤数据（含多条记录）
  DateTime _selectedDate = DateTime.now(); // 选中的日期
  Map<String, dynamic>? _pendingApplication;
  List<Map<String, dynamic>> _mySites = [];
  List<Map<String, dynamic>> _availableSites = [];
  List<Map<String, dynamic>> _lockedWorkers = [];
  bool _hasPendingApplication = false;
  bool _hasSite = false;
  bool _isSuperAdmin = false;

  // 搜索用
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadLockedWorkers();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getInternalHome();
      if (!mounted) return;

      // 获取选中日期的考勤
      Map<String, dynamic>? attData;
      try {
        final dateStr = _selectedDate.toIso8601String().split('T')[0];
        attData = await _api.internalGetDailyAttendance(dateStr);
      } catch (_) {
        // 考勤数据不影响首页主流程，静默
      }

      if (!mounted) return;
      setState(() {
        _homeData = data;
        _currentSite = data['currentSite'];
        _hasSite = data['hasSite'] == true;
        _hasPendingApplication = data['hasPendingApplication'] == true;
        _pendingApplication = data['pendingApplication'];
        _mySites = (data['mySites'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _availableSites = (data['availableSites'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _attendanceData = attData;
        _isSuperAdmin = data['user']?['role'] == 'SUPER_ADMIN';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加載失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _loadLockedWorkers() async {
    try {
      final data = await _api.getLockedWorkers();
      if (!mounted) return;
      setState(() => _lockedWorkers = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加載鎖卡列表失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(isoTime).toLocal());
    } catch (_) {
      return isoTime;
    }
  }

  // ==================== 地盘切换 ====================

  void _showSiteSwitcher() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('切換地盤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_mySites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('暫未加入任何地盤', style: TextStyle(color: AppTheme.textSecondary))),
                )
              else
                ..._mySites.map((site) {
                  final isCurrent = site['isCurrent'] == true;
                  final name = site['name'] ?? '未知地盤';
                  return ListTile(
                    leading: Icon(
                      isCurrent ? Icons.check_circle : Icons.location_on,
                      color: isCurrent ? AppTheme.primaryColor : AppTheme.textHint,
                    ),
                    title: Text(name, style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppTheme.primaryColor : AppTheme.textPrimary,
                    )),
                    subtitle: site['address'] != null ? Text(site['address'], style: const TextStyle(fontSize: 12)) : null,
                    trailing: isCurrent ? const Icon(Icons.chevron_right, color: AppTheme.primaryColor) : null,
                    onTap: isCurrent ? null : () async {
                      Navigator.pop(ctx);
                      await _switchSite(site['siteId'] as int);
                    },
                  );
                }),
              const SizedBox(height: 16),
              // 申请加入地盘入口
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showApplySiteDialog();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('申請加入新地盤'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchSite(int siteId) async {
    try {
      await _api.switchSite(siteId);
      _showSnackBar('已切換地盤', isError: false);
      _loadData();
    } catch (e) {
      _showSnackBar('切換失敗：${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  // ==================== 加入地盘 ====================

  void _showApplySiteDialog() {
    if (_availableSites.isEmpty) {
      _showSnackBar('暫無可申請的地盤');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('申請加入地盤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_availableSites.isEmpty)
                const Center(child: Text('暫無可申請的地盤'))
              else
                ..._availableSites.map((site) {
                  final name = site['name'] ?? '未知地盤';
                  return ListTile(
                    leading: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                    title: Text(name),
                    subtitle: site['address'] != null ? Text(site['address'], style: const TextStyle(fontSize: 12)) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      _applySite(site['id'] as int);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applySite(int siteId) async {
    try {
      final result = await _api.applyInternalSite(siteId);
      if (!mounted) return;
      final autoApproved = result['autoApproved'] == true;
      if (autoApproved) {
        _showSnackBar('已自動加入地盤', isError: false);
      } else {
        _showSnackBar('申請已提交，請等待審批', isError: false);
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('申請失敗：${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  Future<void> _cancelApplication() async {
    try {
      await _api.cancelInternalSiteApplication();
      _showSnackBar('申請已撤銷', isError: false);
      _loadData();
    } catch (e) {
      _showSnackBar('撤銷失敗：${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  // ==================== + 菜单 ====================

  void _showPlusMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 48, kToolbarHeight + MediaQuery.of(context).padding.top + 4,
        MediaQuery.of(context).size.width - 8, kToolbarHeight + MediaQuery.of(context).padding.top + 48,
      ),
      items: [
        const PopupMenuItem(value: 'scan', child: ListTile(
          leading: Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor),
          title: Text('掃一掃'),
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        )),
        if (_isSuperAdmin)
          const PopupMenuItem(value: 'blacklist', child: ListTile(
            leading: Icon(Icons.block, color: AppTheme.errorColor),
            title: Text('加黑名單'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          )),
      ],
    ).then((value) {
      if (value == 'scan') {
        _openScanner();
      } else if (value == 'blacklist') {
        _showBlacklistDialog();
      }
    });
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanDeductPage()),
    );
  }

  void _showBlacklistDialog() {
    final phoneCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final safetyCardCtrl = TextEditingController();
    String? _attachmentUrl;
    String? _attachmentName;
    bool _uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [Icon(Icons.block, color: AppTheme.errorColor, size: 22), SizedBox(width: 8), Text('加黑名單')],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('輸入工人手機號碼後可直接修改黑名單狀態',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  // 手机号（必填）
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '工人手機號碼 *',
                      hintText: '請輸入工人手機號碼',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.phone, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 平安卡号码
                  TextField(
                    controller: safetyCardCtrl,
                    decoration: const InputDecoration(
                      labelText: '平安卡號碼',
                      hintText: '選填',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.credit_card, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 平安卡附件上传
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                            );
                            if (result == null || result.files.isEmpty) return;
                            final file = result.files.first;
                            setDialogState(() => _uploading = true);
                            try {
                              final bytes = file.bytes ?? await File(file.path!).readAsBytes();
                              final url = await _api.uploadFile(
                                bytes: bytes,
                                filename: file.name,
                                folder: 'safety-cards',
                              );
                              setDialogState(() {
                                _attachmentUrl = url;
                                _attachmentName = file.name;
                                _uploading = false;
                              });
                            } catch (e) {
                              setDialogState(() => _uploading = false);
                              _showSnackBar('上傳失敗：$e');
                            }
                          },
                          icon: _uploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file, size: 18),
                          label: Text(_uploading ? '上傳中...' : '上傳平安卡附件'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _attachmentUrl != null ? AppTheme.successColor : null,
                          ),
                        ),
                      ),
                      if (_attachmentName != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(_attachmentName!, style: const TextStyle(fontSize: 11, color: AppTheme.successColor), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 原因
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: '黑名單原因',
                      hintText: '請填寫原因',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneCtrl.text.trim();
                final reason = reasonCtrl.text.trim();
                final safetyCard = safetyCardCtrl.text.trim();
                if (phone.isEmpty) {
                  _showSnackBar('請輸入手機號碼');
                  return;
                }
                if (reason.isEmpty) {
                  _showSnackBar('請填寫黑名單原因');
                  return;
                }
                Navigator.pop(ctx);
                await _blacklistByPhone(phone, reason, safetyCard, _attachmentUrl);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
              child: const Text('確認加入黑名單'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blacklistByPhone(String phone, String reason, String safetyCardNumber, String? attachmentUrl) async {
    try {
      final result = await _api.blacklistByPhone(
        phone: phone,
        reason: reason,
        safetyCardNumber: safetyCardNumber.isNotEmpty ? safetyCardNumber : null,
        safetyCardAttachment: attachmentUrl,
      );
      if (!mounted) return;
      final name = result['chineseName'] ?? result['workerNumber'] ?? phone;
      _showSnackBar('已將 $name 加入黑名單', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('操作失敗：${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  /// 内部人员打卡
  Future<void> _internalCheckIn() async {
    if (!_hasSite) {
      _showSnackBar('請先選擇一個地盤');
      return;
    }
    try {
      final result = await _api.internalCheckIn();
      if (!mounted) return;
      final hasCheckOut = result['checkOutTime'] != null;
      _showSnackBar(hasCheckOut ? '已簽退' : '已簽到', isError: false);
      setState(() => _selectedDate = DateTime.now()); // 回到今天
      _loadData(); // 刷新考勤状态
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('打卡失敗：${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  // ==================== 锁卡工人解锁 ====================

  Future<void> _unlockWorker(Map<String, dynamic> worker) async {
    try {
      await _api.toggleWorkerLock(worker['id'] as int, false);
      _showSnackBar('已解鎖', isError: false);
      _loadLockedWorkers();
    } catch (e) {
      _showSnackBar('解鎖失敗：${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final pages = [_buildHome(), _buildProfilePage()];
    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) { _loadData(); _loadLockedWorkers(); }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首頁'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '個人中心'),
        ],
      ),
    );
  }

  // ==================== Tab 0: 首页 ====================

  Widget _buildHome() {
    final user = _homeData?['user'];
    final name = user?['name'] ?? '內部工作人員';
    final siteName = _currentSite?['name'];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('遠東工友'), automaticallyImplyLeading: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('遠東工友'),
        automaticallyImplyLeading: false,
        actions: [
          GestureDetector(
            onTap: _showPlusMenu,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _loadData(); await _loadLockedWorkers(); },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 天气警告栏（用户卡片上方）
              const WeatherWarningBar(isInternal: true),
              // 用户信息卡片
              _buildUserCard(name, siteName),
              const SizedBox(height: 20),

              // 申请中/无地盘提示
              if (_hasPendingApplication)
                _buildPendingCard()
              else if (!_hasSite)
                _buildNoSiteCard(),

              // 快捷功能
              const Text('快捷功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 24),

              // 今日考勤
              const Text('今日考勤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildAttendanceCard(),
              const SizedBox(height: 24),

              // 被锁卡工人列表
              if (_lockedWorkers.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('被鎖卡工人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_lockedWorkers.length}人', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                ..._lockedWorkers.map(_buildLockedWorkerCard),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(String name, String? siteName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('歡迎', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_homeData?['user']?['role'] ?? '',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 12),
          // 地盘信息 - 可点击切换
          GestureDetector(
            onTap: _hasSite || _mySites.isNotEmpty ? _showSiteSwitcher : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasSite ? Icons.location_on : Icons.location_off,
                    color: Colors.white, size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _hasSite ? siteName! : '暫無地盤',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (_mySites.length > 1) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7), size: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSiteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('尚未加入地盤', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('請先申請加入一個地盤後開始工作',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showApplySiteDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('申請加入地盤'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    final siteName = _pendingApplication?['siteName'] ?? '未知地盤';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_empty, color: AppTheme.warningColor, size: 20),
              const SizedBox(width: 8),
              const Text('申請加入地盤中', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('目標地盤：$siteName', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          const Text('請等待 SITE_MANAGER 審批', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelApplication,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('撤銷申請'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final canCheckIn = _hasSite;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _quickAction(Icons.fingerprint, '打卡', canCheckIn, () => _internalCheckIn()),
        _quickAction(Icons.smart_display, '安全培訓', true, () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyVideosPage()))),
        _quickAction(Icons.add_location, '申請地盤', true, _showApplySiteDialog),
        _quickAction(Icons.lock_open, '解鎖工人', _lockedWorkers.isNotEmpty, () {
          _currentIndex = 0; // scroll down to locked workers
        }),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, bool enabled, VoidCallback? onTap) {
    final disabled = !enabled || onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: disabled ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: disabled ? Colors.grey.shade400 : AppTheme.primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: disabled ? Colors.grey.shade400 : AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final records = (_attendanceData?['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalDuration = _attendanceData?['totalDuration'] ?? '';
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateStr = '${_selectedDate.month}/${_selectedDate.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行 + 日期选择
        Row(
          children: [
            const Text('考勤記錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(isToday ? '今日' : dateStr,
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (records.isNotEmpty)
              Text('$totalDuration', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),

        // 无记录
        if (records.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 40, color: AppTheme.textHint.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(isToday ? '今日尚未打卡' : '該日無打卡記錄',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    if (isToday) ...[
                      const SizedBox(height: 4),
                      const Text('點擊上方「打卡」按鈕簽到',
                          style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          // 时间轴卡片列表
          ...records.map((r) => _buildTimelineCard(r)),
      ],
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> record) {
    final siteName = record['siteName'] ?? '未知地盤';
    final checkInTime = record['checkInTime'] as String?;
    final checkOutTime = record['checkOutTime'] as String?;
    final duration = record['duration'] ?? '';
    final isCompleted = checkOutTime != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 状态图标
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.successColor.withOpacity(0.1)
                    : AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.schedule,
                color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(siteName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.login, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(_formatTime(checkInTime), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 8),
                      if (checkOutTime != null) ...[
                        Icon(Icons.logout, size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Text(_formatTime(checkOutTime), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ] else ...[
                        Text('簽退中...', style: TextStyle(fontSize: 13, color: AppTheme.warningColor)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 时长
            if (duration.toString().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(duration, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: isCompleted ? AppTheme.primaryColor : AppTheme.warningColor,
                )),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'TW'),
    );
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _loadAttendanceForDate();
    }
  }

  Future<void> _loadAttendanceForDate() async {
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final attData = await _api.internalGetDailyAttendance(dateStr);
      if (!mounted) return;
      setState(() => _attendanceData = attData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加載考勤記錄失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
  }

  Widget _buildLockedWorkerCard(Map<String, dynamic> worker) {
    final name = worker['chineseName'] ?? worker['englishName'] ?? '未知';
    final workerNum = worker['workerNumber'] ?? '';
    final siteName = worker['siteName'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.errorColor.withOpacity(0.2),
          child: Text(name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
        ),
        title: Text('$name ($workerNum)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: siteName.isNotEmpty
            ? Text(siteName, style: const TextStyle(fontSize: 12))
            : null,
        trailing: TextButton(
          onPressed: () => _unlockWorker(worker),
          style: TextButton.styleFrom(foregroundColor: AppTheme.successColor),
          child: const Text('解鎖', style: TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  // ==================== Tab 1: 个人中心 ====================

  Widget _buildProfilePage() {
    final user = _homeData?['user'];
    final name = user?['name'] ?? '內部工作人員';
    final phone = user?['phone'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('個人中心'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: Text(name.isNotEmpty ? name[0] : '內',
                      style: const TextStyle(color: Colors.white, fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(user?['role'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(phone, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(Icons.credit_card_outlined, '考勤記錄', () => _showAttendanceDialog()),
          _buildMenuItem(Icons.notifications_outlined, '通知中心', () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
          }),
          const Divider(height: 32),
          _buildMenuItem(Icons.logout, '退出登入', () async {
            await _api.logout();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/login');
          }, color: AppTheme.errorColor),
        ],
      ),
    );
  }

  /// 显示内部人员考勤记录弹窗
  void _showAttendanceDialog() {
    final records = (_attendanceData?['records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalDuration = _attendanceData?['totalDuration'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('考勤記錄'),
        content: SizedBox(
          width: double.maxFinite,
          child: records.isEmpty
              ? const Text('今日尚未打卡', style: TextStyle(fontSize: 14))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...records.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(r['checkOutTime'] != null ? Icons.check_circle : Icons.schedule,
                              size: 16, color: r['checkOutTime'] != null ? AppTheme.successColor : AppTheme.warningColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${r['siteName'] ?? ''}  ${_formatTime(r['checkInTime'])} → ${r['checkOutTime'] != null ? _formatTime(r['checkOutTime']) : '進行中'}'),
                          ),
                          if (r['duration'] != null)
                            Text('${r['duration']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    )),
                    if (totalDuration.toString().isNotEmpty) ...[
                      const Divider(),
                      Text('總工時：$totalDuration', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉'))],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textPrimary, size: 22),
        title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
