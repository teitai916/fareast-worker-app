import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/pages/worker/change_site_page.dart';
import 'package:fareast_worker_app/pages/worker/change_company_page.dart';
import 'package:fareast_worker_app/pages/worker/attendance_page.dart';
import 'package:fareast_worker_app/pages/worker/safety_videos_page.dart';
import 'package:fareast_worker_app/pages/worker/site_apply_page.dart';
import 'package:fareast_worker_app/pages/notifications_page.dart';
import 'package:fareast_worker_app/widgets/weather_warning_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  final _api = ApiService();
  int _currentIndex = 0;
  late final PageController _pageController;
  bool _loading = true;
  String? _error;
  DateTime? _lastBackTime; // 双击退出
  int _unreadNotifications = 0; // 未读通知数

  // 工人首页数据
  Map<String, dynamic>? _homeData;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _currentSite;
  Map<String, dynamic>? _todayAttendance; // 今日考勤
  String? _workerNumber;
  int _siteSafetyScore = 15; // 地盤安全分（15分制）
  String? _companyName; // 所屬公司名稱
  bool _checkInAllowed = true; // 必修安全影片是否全部完成
  bool _isLocked = false; // 是否被鎖卡/黑名單
  bool _hasPendingApplication = false; // 是否有待審核的申請

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getWorkerHome();
      if (!mounted) return;

      // 获取今日考勤
      Map<String, dynamic>? todayAtt;
      try {
        final today = DateTime.now().toIso8601String().split('T')[0];
        todayAtt = await _api.getDailyAttendance(today);
      } catch (e) {
        // 无打卡记录，忽略
      }

      if (!mounted) return;

      // 檢查安全影片是否全部完成
      bool checkInAllowed = true;
      try {
        checkInAllowed = await _api.isSafetyCheckInAllowed();
      } catch (e) {
        // 查詢失敗，預設允許打卡
      }

      if (!mounted) return;

      // 獲取地盤安全分（按地盤維度，總分15分）
      int siteSafetyScore = 15; // 預設15分
      try {
        final safetyData = await _api.getSiteSafetyScore();
        siteSafetyScore = safetyData['safetyScore'] as int? ?? 15;
      } catch (e) {
        // 獲取失敗，使用預設值
      }

      if (!mounted) return;

      // 获取未读通知数（角标用）
      _loadUnreadCount();

      setState(() {
        _homeData = data;
        _profile = data['profile'];
        _currentSite = data['currentSite'];
        _todayAttendance = todayAtt;
        _workerNumber = _profile?['workerNumber'];
        _siteSafetyScore = siteSafetyScore;
        _companyName = _profile?['companyName'] ?? '';
        _checkInAllowed = checkInAllowed;
        // 檢查是否被鎖卡或黑名單：只要任一為 true 就鎖定
        _isLocked = (_profile?['cardLocked'] == true || _profile?['blacklisted'] == true);
        _hasPendingApplication = data['pendingApplication'] != null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /// 格式化時間字符串（ISO 8601 -> HH:mm）
  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return isoTime;
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _api.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) { /* 静默，角标非关键功能 */ }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('加載失敗', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [_buildHome(), _buildSitePage(), _buildProfilePage()];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackTime == null || now.difference(_lastBackTime!) > const Duration(seconds: 2)) {
          _lastBackTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('再按一次返回鍵退出'), duration: Duration(seconds: 2)),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) _loadData();
        },
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首頁'),
          const BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: '地盤'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text('${_unreadNotifications > 99 ? '99+' : _unreadNotifications}'),
              child: const Icon(Icons.person_outline),
            ),
            label: '我的',
          ),
        ],
      ),
    ));
  }

  Widget _buildHome() {
    final user = TokenManager.currentUser;
    final name = user?.name ?? '工友';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('遠東工友通'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('遠東工友通'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重試')),
          ]),
        ),
      );
    }

    final siteName = _currentSite?['name'];
    final hasSite = siteName != null;
    final hasCompany = (_profile?['currentCompanyId'] as int?) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('遠東工友通'),
        automaticallyImplyLeading: false,
        actions: [
          if (!hasSite && !_isLocked && !_hasPendingApplication)
            TextButton.icon(
              onPressed: () => _showApplySiteSheet(context),
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
              label: const Text('申請加入', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          IconButton(
            onPressed: _workerNumber != null ? () => _showQrCodeDialog() : null,
            icon: const Icon(Icons.qr_code, size: 24),
            tooltip: '工人編碼二維碼',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 天气警告栏（用户卡片上方）
              const WeatherWarningBar(),
              // 用户信息卡片
              Container(
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
                    Text('歡迎回來', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('編號：${_workerNumber ?? '—'}',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isLocked ? AppTheme.errorColor.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLocked ? Icons.lock : (hasSite ? Icons.location_on : Icons.location_off),
                            color: Colors.white, size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isLocked ? '帳號已被鎖定' : (hasSite ? siteName : '暫無地盤，請申請加入'),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 无地盘提示
              if (!hasSite && !_isLocked && !_hasPendingApplication) ...[
                Container(
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
                            Text(
                              _hasPendingApplication ? '申請審核中' : '尚未加入地盤',
                              style: TextStyle(fontWeight: FontWeight.bold, color: _hasPendingApplication ? AppTheme.primaryColor : AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasPendingApplication ? '您的申請正在審核中，請耐心等待判頭公司審批'
                                  : '點擊左上角「申請加入」按鈕或下方按鈕，選擇要加入的地盤',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            if (!_hasPendingApplication) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showApplySiteSheet(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('申請加入地盤'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 快捷功能
              const Text('快捷功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(hasSite, hasCompany),
              const SizedBox(height: 24),

              // 今日考勤
              const Text('今日考勤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_todayAttendance != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _todayAttendance!['checkOutTime'] != null
                                    ? AppTheme.successColor.withOpacity(0.1)
                                    : AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _todayAttendance!['checkOutTime'] != null
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: _todayAttendance!['checkOutTime'] != null
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _todayAttendance!['checkOutTime'] != null ? '今日已完成打卡' : '已簽到，未簽退',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_todayAttendance!['checkInTime'] != null)
                                    Text(
                                      '簽到：${_formatTime(_todayAttendance!['checkInTime'])}',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                  if (_todayAttendance!['checkOutTime'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '簽退：${_formatTime(_todayAttendance!['checkOutTime'])}',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                  if (_todayAttendance!['siteName'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '地點：${_todayAttendance!['siteName']}',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasSite ? AppTheme.warningColor.withOpacity(0.1) : AppTheme.textHint.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            hasSite ? Icons.schedule : Icons.location_off,
                            color: hasSite ? AppTheme.warningColor : AppTheme.textHint,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hasSite ? '尚未打卡' : '請先加入地盤',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(hasSite ? '點擊上方「打卡」按鈕簽到' : '加入地盤後方可打卡',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSitePage() {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('地盤信息'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasSite = _currentSite != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('地盤信息'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前地盘
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: hasSite ? AppTheme.primaryColor : AppTheme.textHint),
                    const SizedBox(width: 8),
                    Text(hasSite ? '當前地盤' : '暫無地盤',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasSite) ...[
                  Text(_currentSite!['name'] ?? '', style: const TextStyle(fontSize: 16)),
                  if (_currentSite!['address'] != null) ...[
                    const SizedBox(height: 4),
                    Text('地址：${_currentSite!['address']}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                  if (_currentSite!['managerName'] != null) ...[
                    const SizedBox(height: 4),
                    Text('管理員：${_currentSite!['managerName']}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _isLocked
                        ? ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.lock, size: 20),
                            label: const Text('帳號已被鎖定，無法更換地盤'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.grey.shade600,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeSitePage())),
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            label: const Text('更換地盤'),
                          ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _hasPendingApplication ? Icons.hourglass_empty : Icons.location_off,
                          color: _hasPendingApplication ? AppTheme.primaryColor : AppTheme.warningColor,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasPendingApplication ? '申請審核中' : '您尚未加入任何地盤',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasPendingApplication ? '您的申請正在審核中，請耐心等待判頭公司審批'
                              : '請聯繫判頭或管理員安排地盤',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        if (!_hasPendingApplication) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showApplySiteSheet(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('申請加入地盤'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 锁定状态警告
          if (_isLocked)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: AppTheme.errorColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('帳號已被鎖定，更換地盤等功能暫不可用',
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                  ),
                ],
              ),
            ),

          // 地盤安全
          const Text('地盤安全', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatItem('工人編號', _workerNumber ?? '—', AppTheme.infoColor)),
                      Expanded(child: _buildStatItem('所屬公司', _getCompanyName(), AppTheme.textSecondary)),
                      Expanded(child: _buildSafetyScoreItem()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final user = TokenManager.currentUser;
    final name = user?.name ?? '工友';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('個人中心'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人中心'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 合併卡片：個人資料 + 所屬公司 ───
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/worker/register'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  // 左侧：头像
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(name.isNotEmpty ? name[0] : '工',
                        style: const TextStyle(color: Colors.white, fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  // 中间：姓名 + 公司
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.business, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                (_companyName != null && _companyName!.isNotEmpty)
                                    ? _companyName!
                                    : '暫無公司',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _companyName != null && _companyName!.isNotEmpty
                                      ? AppTheme.textSecondary
                                      : AppTheme.textHint,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 右侧：箭头
                  Icon(Icons.chevron_right, color: AppTheme.textHint, size: 28),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          _buildMenuItem(Icons.videocam_outlined, '安全培訓影片', () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyVideosPage()))),
          _buildMenuItem(Icons.credit_card_outlined, '考勤記錄', () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage()))),
          _buildMenuItem(Icons.notifications_outlined, '通知中心', () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
            _loadData(); // 返回后刷新
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

  void _showApplySiteSheet(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SiteApplyPage(onApplied: _loadData)));
  }

  /// 構建快捷功能網格（固定4列，最多顯示7個+「更多」）
  Widget _buildQuickActionsGrid(bool hasSite, bool hasCompany) {
    // 鎖定狀態下所有功能 disabled
    final canCheckIn = !_isLocked && hasSite && _checkInAllowed;
    final canTrain = !_isLocked && hasSite;
    final canChangeSite = !_isLocked && hasSite;
    final canChangeCompany = !_isLocked && hasCompany;
    final actions = [
      _QuickActionData(Icons.fingerprint, '打卡', canCheckIn, () {
        HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage()));
      }),
      _QuickActionData(Icons.smart_display, '安全培訓', canTrain, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyVideosPage()))),
      _QuickActionData(Icons.swap_horiz, '更換地盤', canChangeSite, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeSitePage()))),
      _QuickActionData(Icons.business, '更換公司', canChangeCompany, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeCompanyPage()))),
    ];

    // 前7個顯示 + 第8個固定為「更多」
    const int maxVisible = 7;
    final visible = actions.length > maxVisible
        ? actions.sublist(0, maxVisible)
        : actions;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 0,
        runSpacing: 8,
        children: [
          ...visible.map((a) => _buildGridItem(a)),
          if (actions.length > maxVisible) _buildMoreGridItem(),
        ],
      ),
    );
  }

  /// 單個網格按鈕（固定寬度 25%）
  Widget _buildGridItem(_QuickActionData action) {
    final disabled = !action.enabled;
    return SizedBox(
      width: MediaQuery.of(context).size.width / 4 - 12,
      child: GestureDetector(
        onTap: disabled ? null : action.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: disabled ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: disabled ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Icon(action.icon, color: disabled ? Colors.grey.shade400 : AppTheme.primaryColor, size: 28),
              const SizedBox(height: 8),
              Text(action.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: disabled ? Colors.grey.shade400 : AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  /// 「更多」按鈕（田字格圖標）
  Widget _buildMoreGridItem() {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 4 - 12,
      child: GestureDetector(
        onTap: () => _showMoreMenu(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Column(
            children: [
              Icon(Icons.apps, color: AppTheme.primaryColor, size: 28),
              SizedBox(height: 8),
              Text('更多', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  /// 顯示更多功能菜單（BottomSheet）
  void _showMoreMenu() {
    final hasSite = _currentSite != null;
    final hasCompany = (_profile?['currentCompanyId'] as int?) != null;
    final canCheckIn = !_isLocked && hasSite && _checkInAllowed;
    final canTrain = !_isLocked && hasSite;
    final canChangeSite = !_isLocked && hasSite;
    final canChangeCompany = !_isLocked && hasCompany;
    final allActions = [
      _QuickActionData(Icons.fingerprint, '打卡', canCheckIn, () {
        HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendancePage()));
      }),
      _QuickActionData(Icons.smart_display, '安全培訓', canTrain, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyVideosPage()))),
      _QuickActionData(Icons.swap_horiz, '更換地盤', canChangeSite, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeSitePage()))),
      _QuickActionData(Icons.business, '更換公司', canChangeCompany, () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeCompanyPage()))),
    ];

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
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('全部功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 0,
                  childAspectRatio: 0.85,
                ),
                itemCount: allActions.length,
                itemBuilder: (_, i) {
                  final a = allActions[i];
                  final disabled = !a.enabled;
                  return GestureDetector(
                    onTap: disabled ? null : () {
                      Navigator.pop(ctx);
                      a.onTap?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: disabled ? Colors.grey.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: disabled ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(a.icon, color: disabled ? Colors.grey.shade400 : AppTheme.primaryColor, size: 28),
                          const SizedBox(height: 6),
                          Text(a.label,
                              style: TextStyle(fontSize: 12,
                                  color: disabled ? Colors.grey.shade400 : AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  /// 獲取所屬公司名稱
  String _getCompanyName() {
    if (_companyName != null && _companyName!.isNotEmpty) {
      return _companyName!;
    }
    // 如果 profile 中沒有公司名稱，嘗試從 currentSite 獲取
    if (_currentSite != null && _currentSite!['companyName'] != null) {
      return _currentSite!['companyName'];
    }
    return '—';
  }

  /// 显示工人编码二维码弹窗
  void _showQrCodeDialog() {
    if (_workerNumber == null || _workerNumber!.isEmpty) return;
    final qrSize = MediaQuery.of(context).size.width * 0.55;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('工人編碼', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RepaintBoundary(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: _workerNumber!,
                      version: QrVersions.auto,
                      size: qrSize.clamp(180, 260),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                _workerNumber!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('關閉'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 構建安全分顯示項（按地盤維度，總分15分，低於5分顯示紅色）
  Widget _buildSafetyScoreItem() {
    // 使用地盤安全分（總分15分）
    final color = _siteSafetyScore < 5 ? AppTheme.errorColor : AppTheme.successColor;
    
    return Column(
      children: [
        Text('$_siteSafetyScore分', 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        const Text('安全分', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textPrimary, size: 22),
        title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary)),
        trailing: Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
        onTap: onTap,
      ),
    );
  }
}

/// 快捷功能數據模型
class _QuickActionData {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _QuickActionData(this.icon, this.label, this.enabled, this.onTap);
}
