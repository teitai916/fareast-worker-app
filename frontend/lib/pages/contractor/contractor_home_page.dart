import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/utils/password_validator.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/services/biometric_service.dart';
import 'package:fareast_worker_app/pages/notifications_page.dart';
import 'package:fareast_worker_app/widgets/empty_state_widget.dart';

class ContractorHomePage extends StatefulWidget {
  const ContractorHomePage({super.key});

  @override
  State<ContractorHomePage> createState() => _ContractorHomePageState();
}

class _ContractorHomePageState extends State<ContractorHomePage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;
  DateTime? _lastBackTime;
  int _unreadNotificationCount = 0;
  int _pendingCount = 0;
  int _pendingAppCount = 0;   // 入盘申请待审核数
  int _pendingChangeCount = 0;  // 更换地盘待审核数
  int _pendingCompanyCount = 0;  // 更换公司待审核数
  final _api = ApiService();
  late TabController _auditTabController;

  final pages = [null, null, null]; // 懒加载

  // 地盘管理相关状态
  List<dynamic> _sites = [];
  int? _selectedSiteId;
  String _selectedSiteName = '全部地盘';
  List<dynamic> _workers = [];
  Map<String, dynamic> _stats = {'total': 0, 'checkedIn': 0, 'absent': 0};
  bool _isLoadingSites = false;
  bool _isLoadingWorkers = false;

  // 审核列表状态
  bool _loadingApps = true;
  List<dynamic> _applications = [];
  bool _loadingChanges = true;
  List<dynamic> _changeRequests = [];
  bool _loadingCompanyChanges = true;
  List<dynamic> _companyChangeRequests = [];
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _auditTabController = TabController(length: 3, vsync: this);
    _loadUnreadCount();
    _loadPendingCount();
    _loadSites();
    _loadApplications();
    _loadChangeRequests();
    _loadCompanyChangeRequests();
  }

  @override
  void dispose() {
    _auditTabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);
    try {
      final sites = await _api.getContractorSites();
      if (mounted) {
        setState(() {
          _sites = sites;
          _isLoadingSites = false;
        });
        // 默认加载全部工人
        _loadWorkers();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSites = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);
    try {
      final data = await _api.getSiteWorkers(siteId: _selectedSiteId);
      if (mounted) {
        setState(() {
          _workers = data['workers'] as List<dynamic>;
          _stats = data['stats'] as Map<String, dynamic>;
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWorkers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _api.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadNotificationCount = count);
    } catch (e) {
      // 通知数量 - 后台静默，不影响主流程
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await _api.getPendingApplicationCount();
      if (mounted) setState(() => _pendingCount = count);
    } catch (e) {
      // 通知数量 - 后台静默，不影响主流程
    }
  }

  // ─── 审核数据加载 ───
  Future<void> _loadApplications() async {
    try {
      final data = await _api.getContractorApplications();
      if (!mounted) return;
      final pendingCount = data.where((a) => a['status'] == 'PENDING').length;
      setState(() {
        _applications = data;
        _loadingApps = false;
        _pendingAppCount = pendingCount;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingApps = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _loadChangeRequests() async {
    try {
      final data = await _api.getChangeRequests();
      if (!mounted) return;
      final pendingCount = data.where((a) => a['status'] == 'PENDING').length;
      setState(() {
        _changeRequests = data;
        _loadingChanges = false;
        _pendingChangeCount = pendingCount;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _loadCompanyChangeRequests() async {
    try {
      final data = await _api.getContractorCompanyChangeRequests();
      if (!mounted) return;
      final pendingCount = data.where((a) => a['status'] == 'PENDING').length;
      setState(() {
        _companyChangeRequests = data;
        _loadingCompanyChanges = false;
        _pendingCompanyCount = pendingCount;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingCompanyChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (i == 0) {
            _loadSites();
            _loadWorkers();
          } else if (i == 1) {
            _loadUnreadCount();
            _loadPendingCount();
            _loadApplications();
            _loadChangeRequests();
            _loadCompanyChangeRequests();
          }
        },
        children: [
          _buildSiteManagement(),
          _buildAuditPage(),
          _buildProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.location_city_outlined),
            label: '地盘管理',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.rate_review_outlined),
                if (_pendingCount > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        _pendingCount > 99 ? '99+' : '$_pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: '审核',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    ));
  }

  Widget _buildSiteManagement() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地盘管理'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWorkers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Site selector
            _isLoadingSites
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<int?>(
                    decoration: InputDecoration(
                      labelText: '选择地盘',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    value: _selectedSiteId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('全部地盘')),
                      ..._sites.map((site) => DropdownMenuItem<int?>(
                            value: site['id'] as int,
                            child: Text(site['name'] ?? '未知地盘'),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSiteId = value;
                        _selectedSiteName = value == null
                            ? '全部地盘'
                            : (_sites.firstWhere(
                                    (s) => s['id'] == value,
                                    orElse: () => {'name': '未知地盘'})['name'] ??
                                '未知地盘');
                      });
                      _loadWorkers();
                    },
                  ),
            const SizedBox(height: 16),

            // Worker count card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('工人总数', '${_stats['total'] ?? 0}', AppTheme.primaryColor),
                    _buildStatColumn('今日出勤', '${_stats['checkedIn'] ?? 0}', AppTheme.successColor),
                    _buildStatColumn('缺席', '${_stats['absent'] ?? 0}', AppTheme.warningColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Workers in site
            Row(
              children: [
                const Text('地盘工人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (_isLoadingWorkers)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_workers.isEmpty && !_isLoadingWorkers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: EmptyStateWidget(icon: Icons.person_off, title: '暫無工人'),
                ),
              )
            else
              ..._workers.map((worker) => _buildWorkerListItem(worker)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildWorkerListItem(Map<String, dynamic> worker) {
    final name = worker['name'] ?? '未知';
    final bool lockCard = worker['cardLocked'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white)),
        ),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (lockCard)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('锁卡', style: TextStyle(color: AppTheme.errorColor, fontSize: 10)),
              ),
          ],
        ),
        subtitle: Text('${worker['siteName'] ?? ''} | 安全分：${worker['safetyScore'] ?? '-'}'),
      ),
    );
  }

  /// 审核页面：嵌入三个审核列表（入盤申請 / 更換地盤 / 更換公司）
  Widget _buildAuditPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('审核管理'),
        automaticallyImplyLeading: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsPage()),
                  );
                  _loadUnreadCount();
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _auditTabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            _buildTabWithBadge('入盤申請', _pendingAppCount),
            _buildTabWithBadge('更換地盤', _pendingChangeCount),
            _buildTabWithBadge('更換公司', _pendingCompanyCount),
          ],
        ),
      ),
      body: TabBarView(
        controller: _auditTabController,
        children: [
          _buildAppList(),
          _buildChangeList(),
          _buildCompanyChangeList(),
        ],
      ),
    );
  }

  /// 构建带红色待审核数字的 Tab 标签
  Widget _buildTabWithBadge(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 审核列表 - 入盤申請
  // ═══════════════════════════════════════════════
  Widget _buildAppList() {
    if (_loadingApps) return const Center(child: CircularProgressIndicator());
    if (_applications.isEmpty) {
      return const EmptyStateWidget(icon: Icons.inbox, title: '暫無待審核申請');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      itemBuilder: (_, i) {
        final app = _applications[i];
        final status = app['status'] ?? '';
        final isPending = status == 'PENDING';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(app['workerName'] ?? '未知工人',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('電話：${app['workerPhone'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('地盤：${app['siteName'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('每日薪酬：HK\$ ${app['dailyWage'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (app['contractAttachment'] != null) ...[
                  const SizedBox(height: 8),
                  _buildAttachmentLink(app['contractAttachment']),
                ],
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () => _showReviewDialog(app),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('審核'),
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // 审核列表 - 更換地盤
  // ═══════════════════════════════════════════════
  Widget _buildChangeList() {
    if (_loadingChanges) return const Center(child: CircularProgressIndicator());
    if (_changeRequests.isEmpty) {
      return const EmptyStateWidget(icon: Icons.swap_horiz, title: '暫無待審核更換申請');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _changeRequests.length,
      itemBuilder: (_, i) {
        final req = _changeRequests[i];
        final status = req['status'] ?? '';
        final isPending = status == 'PENDING';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(req['workerName'] ?? '未知工人',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('電話：${req['workerPhone'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('原工地：${req['fromSiteName'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('目標工地：${req['toSiteName'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('每日薪酬：HK\$ ${req['dailyWage'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (req['reason'] != null && req['reason'].toString().isNotEmpty)
                  Text('更換原因：${req['reason']}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (req['contractAttachment'] != null) ...[
                  const SizedBox(height: 8),
                  _buildAttachmentLink(req['contractAttachment']),
                ],
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () => _showReviewChangeDialog(req),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('審核'),
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // 审核列表 - 更換公司
  // ═══════════════════════════════════════════════
  Widget _buildCompanyChangeList() {
    if (_loadingCompanyChanges) return const Center(child: CircularProgressIndicator());
    if (_companyChangeRequests.isEmpty) {
      return const EmptyStateWidget(icon: Icons.business, title: '暫無待審核更換公司申請');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _companyChangeRequests.length,
      itemBuilder: (_, i) {
        final req = _companyChangeRequests[i];
        final status = req['status'] ?? '';
        final isPending = status == 'PENDING';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(req['workerName'] ?? '未知工人',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('電話：${req['workerPhone'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('原公司：${req['fromCompanyName'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('目標公司：${req['toCompanyName'] ?? ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (req['reason'] != null && req['reason'].toString().isNotEmpty)
                  Text('更換原因：${req['reason']}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () => _showReviewCompanyChangeDialog(req),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('審核'),
                  )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 审核辅助方法 ───
  Future<void> _openPdf(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟文件')));
    }
  }

  Widget _buildAttachmentLink(String url) {
    final filename = url.split('/').last;
    String displayName;
    final idx = filename.indexOf('_');
    if (idx > 0 && idx < filename.length - 1) {
      displayName = filename.substring(idx + 1);
    } else {
      displayName = filename;
    }
    return InkWell(
      onTap: () => _openPdf(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('僱傭合約文件：$displayName',
                style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.open_in_new, color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        label = '待審核';
      case 'APPROVED':
        color = Colors.green;
        label = '已批准';
      case 'REJECTED':
        color = Colors.red;
        label = '已拒絕';
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ─── 审批操作 ───
  Future<void> _reviewApp(int appId, bool approved, {String remark = ''}) async {
    try {
      await _api.reviewContractorApplication(applicationId: appId, approved: approved, reviewRemark: remark);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approved ? '已批准申請' : '已拒絕申請'),
        backgroundColor: approved ? Colors.green : AppTheme.errorColor,
      ));
    _loadApplications();
    _refreshBiometricState();
  } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e'), backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _reviewChange(int reqId, bool approved, {String remark = ''}) async {
    try {
      await _api.reviewChangeRequest(requestId: reqId, approved: approved, reviewRemark: remark);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approved ? '已批准更換地盤' : '已拒絕更換地盤'),
        backgroundColor: approved ? Colors.green : AppTheme.errorColor,
      ));
      _loadChangeRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e'), backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _reviewCompanyChange(int reqId, bool approved, {String remark = ''}) async {
    try {
      await _api.reviewCompanyChange(requestId: reqId, approved: approved, reviewRemark: remark);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approved ? '已批准更換公司' : '已拒絕更換公司'),
        backgroundColor: approved ? Colors.green : AppTheme.errorColor,
      ));
      _loadCompanyChangeRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗：$e'), backgroundColor: AppTheme.errorColor));
    }
  }

  // ─── 审批弹窗：入盘申请 ───
  void _showReviewDialog(Map<String, dynamic> app) {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('審核申請'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工人：${app['workerName'] ?? ''}'),
            Text('電話：${app['workerPhone'] ?? ''}'),
            Text('地盤：${app['siteName'] ?? ''}'),
            Text('每日薪酬：HK\$ ${app['dailyWage'] ?? ''}'),
            if (app['contractAttachment'] != null) ...[
              const SizedBox(height: 8),
              _buildAttachmentLink(app['contractAttachment']),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: remarkController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '填寫審核說明（選填）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(child: OutlinedButton(
                onPressed: () { Navigator.pop(context); _reviewApp(app['id'], false, remark: remarkController.text.trim()); },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('拒絕', style: TextStyle(fontSize: 15)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(context); _reviewApp(app['id'], true, remark: remarkController.text.trim()); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('批准', style: TextStyle(fontSize: 15)),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 审批弹窗：更换地盘申请 ───
  void _showReviewChangeDialog(Map<String, dynamic> req) {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('審核更換地盤'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工人：${req['workerName'] ?? ''}'),
            Text('電話：${req['workerPhone'] ?? ''}'),
            Text('原工地：${req['fromSiteName'] ?? ''}'),
            Text('目標工地：${req['toSiteName'] ?? ''}'),
            Text('每日薪酬：HK\$ ${req['dailyWage'] ?? ''}'),
            if (req['reason'] != null && req['reason'].toString().isNotEmpty)
              Text('更換原因：${req['reason']}'),
            if (req['contractAttachment'] != null) ...[
              const SizedBox(height: 8),
              _buildAttachmentLink(req['contractAttachment']),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: remarkController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '填寫審核說明（選填）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(child: OutlinedButton(
                onPressed: () { Navigator.pop(context); _reviewChange(req['id'], false, remark: remarkController.text.trim()); },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('拒絕', style: TextStyle(fontSize: 15)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(context); _reviewChange(req['id'], true, remark: remarkController.text.trim()); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('批准', style: TextStyle(fontSize: 15)),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 审批弹窗：更换公司申请 ───
  void _showReviewCompanyChangeDialog(Map<String, dynamic> req) {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('審核更換公司'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工人：${req['workerName'] ?? ''}'),
            Text('電話：${req['workerPhone'] ?? ''}'),
            Text('原公司：${req['fromCompanyName'] ?? ''}'),
            Text('目標公司：${req['toCompanyName'] ?? ''}'),
            if (req['reason'] != null && req['reason'].toString().isNotEmpty)
              Text('更換原因：${req['reason']}'),
            const SizedBox(height: 12),
            TextField(
              controller: remarkController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '填寫審核說明（選填）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(child: OutlinedButton(
                onPressed: () { Navigator.pop(context); _reviewCompanyChange(req['id'], false, remark: remarkController.text.trim()); },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('拒絕', style: TextStyle(fontSize: 15)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(context); _reviewCompanyChange(req['id'], true, remark: remarkController.text.trim()); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('批准', style: TextStyle(fontSize: 15)),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final user = TokenManager.currentUser;
    final name = user?.name ?? '分判商';
    final phone = user?.phone ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 分判商信息卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 36, backgroundColor: AppTheme.primaryColor,
                  child: Text(name.isNotEmpty ? name[0] : '商', style: const TextStyle(color: Colors.white, fontSize: 28))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('分判商', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 账户信息卡片（全部不可编辑）
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('账户信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoRow('姓名', name),
                const Divider(height: 24),
                _infoRow('手机号码', phone),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(Icons.lock_outline, '修改密碼', _showChangePasswordDialog),
          const SizedBox(height: 8),
          _buildBiometricToggle(),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.logout, '退出登录', () => Navigator.pushReplacementNamed(context, '/login'), color: AppTheme.errorColor),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Future<void> _refreshBiometricState() async {
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometric() async {
    if (_biometricEnabled) {
      await BiometricService.clearCredentials();
      setState(() => _biometricEnabled = false);
    } else {
      final password = await _showEnableBiometricDialog();
      if (password != null && password.isNotEmpty) {
        final user = TokenManager.currentUser;
        if (user != null) {
          await BiometricService.saveCredentials(user.phone, password);
          setState(() => _biometricEnabled = true);
        }
      }
    }
  }

  Future<String?> _showEnableBiometricDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('啟用指紋/面容登入'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '請輸入密碼以確認身份',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('啟用'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildBiometricToggle() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          Icons.fingerprint,
          color: _biometricEnabled ? AppTheme.primaryColor : AppTheme.textHint,
          size: 22,
        ),
        title: Text(
          _biometricEnabled ? '指紋/面容登入：已啟用' : '指紋/面容登入：未啟用',
          style: TextStyle(
            color: _biometricEnabled ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
        subtitle: const Text('點擊切換', style: TextStyle(fontSize: 12)),
        trailing: Icon(
          _biometricEnabled ? Icons.toggle_on : Icons.toggle_off,
          size: 32,
          color: _biometricEnabled ? AppTheme.primaryColor : AppTheme.textHint,
        ),
        onTap: _toggleBiometric,
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final pwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密碼（至少6位）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '確認新密碼',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final pw = pwCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();
              if (pw.isEmpty || confirm.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('請填寫新密碼'), backgroundColor: AppTheme.errorColor),
                );
                return;
              }
              if (pw.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('密碼長度至少為6位'), backgroundColor: AppTheme.errorColor),
                );
                return;
              }
              if (pw != confirm) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('兩次輸入的密碼不一致'), backgroundColor: AppTheme.errorColor),
                );
                return;
              }

              // 密碼複雜度校驗（含手機號/出生日期關聯，在彈窗內攔截，不關閉彈窗）
              final phone = TokenManager.currentUser?.phone;
              final pwdErr = validatePasswordComplexity(pw, phone: phone, birthDate: null);
              if (pwdErr != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(pwdErr), backgroundColor: AppTheme.errorColor),
                );
                pwCtrl.clear();       // 清空新密碼
                confirmCtrl.clear();  // 清空確認密碼
                return;               // 保持彈窗不關閉，讓用戶重輸
              }

              Navigator.pop(ctx, true);
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
    final newPw = pwCtrl.text.trim();
    // 推迟 dispose，避免弹窗控件未完全卸载时 _dependents.isEmpty 断言
    Future.microtask(() {
      pwCtrl.dispose();
      confirmCtrl.dispose();
    });
    if (result == true) {
      try {
        await _api.changePassword(newPw);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密碼修改成功'), backgroundColor: AppTheme.successColor),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失敗：${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textPrimary, size: 22),
        title: Text(title, style: TextStyle(color: color ?? AppTheme.textPrimary)),
        trailing: const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
        onTap: onTap,
      ),
    );
  }
}
