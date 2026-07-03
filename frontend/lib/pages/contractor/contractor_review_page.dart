import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/widgets/empty_state_widget.dart';

class ContractorReviewPage extends StatefulWidget {
  const ContractorReviewPage({super.key});

  @override
  State<ContractorReviewPage> createState() => _ContractorReviewPageState();
}

class _ContractorReviewPageState extends State<ContractorReviewPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();

  late TabController _tabController;

  // 入盘申请
  bool _loadingApps = true;
  List<dynamic> _applications = [];

  // 更换地盘申请
  bool _loadingChanges = true;
  List<dynamic> _changeRequests = [];

  // 更换公司申请
  bool _loadingCompanyChanges = true;
  List<dynamic> _companyChangeRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadApplications();
    _loadChangeRequests();
    _loadCompanyChangeRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── 加载数据 ───
  Future<void> _loadApplications() async {
    try {
      final data = await _api.getContractorApplications();
      if (!mounted) return;
      setState(() {
        _applications = data;
        _loadingApps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingApps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _loadChangeRequests() async {
    try {
      final data = await _api.getChangeRequests();
      if (!mounted) return;
      setState(() {
        _changeRequests = data;
        _loadingChanges = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // ─── 加载数据：更换公司申请 ───
  Future<void> _loadCompanyChangeRequests() async {
    try {
      final data = await _api.getContractorCompanyChangeRequests();
      if (!mounted) return;
      setState(() {
        _companyChangeRequests = data;
        _loadingCompanyChanges = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCompanyChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // ─── 审批：入盘申请 ───
  Future<void> _reviewApp(int appId, bool approved, {String remark = ''}) async {
    try {
      await _api.reviewContractorApplication(
        applicationId: appId,
        approved: approved,
        reviewRemark: remark,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '已批准申請' : '已拒絕申請'),
          backgroundColor: approved ? Colors.green : AppTheme.errorColor,
        ),
      );
      _loadApplications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // ─── 审批：更换地盘申请 ───
  Future<void> _reviewChange(int reqId, bool approved, {String remark = ''}) async {
    try {
      await _api.reviewChangeRequest(
        requestId: reqId,
        approved: approved,
        reviewRemark: remark,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '已批准更換地盤' : '已拒絕更換地盤'),
          backgroundColor: approved ? Colors.green : AppTheme.errorColor,
        ),
      );
      _loadChangeRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // ─── 审批：更换公司申请 ───
  Future<void> _reviewCompanyChange(int reqId, bool approved, {String remark = ''}) async {
    try {
      await _api.reviewCompanyChange(
        requestId: reqId,
        approved: approved,
        reviewRemark: remark,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '已批准更換公司' : '已拒絕更換公司'),
          backgroundColor: approved ? Colors.green : AppTheme.errorColor,
        ),
      );
      _loadCompanyChangeRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：$e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // ─── 打开 PDF ───
  Future<void> _openPdf(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟文件')),
      );
    }
  }

  // ─── 附件链接 Widget ───
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
              child: Text(
                '僱傭合約文件：$displayName',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.open_in_new, color: AppTheme.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── 状态标签 ───
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
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
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reviewApp(app['id'], false, remark: remarkController.text.trim());
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('拒絕', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reviewApp(app['id'], true, remark: remarkController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('批准', style: TextStyle(fontSize: 15)),
                ),
              ),
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
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reviewChange(req['id'], false, remark: remarkController.text.trim());
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('拒絕', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reviewChange(req['id'], true, remark: remarkController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('批准', style: TextStyle(fontSize: 15)),
                ),
              ),
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
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reviewCompanyChange(req['id'], false, remark: remarkController.text.trim());
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('拒絕', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reviewCompanyChange(req['id'], true, remark: remarkController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('批准', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 入盘申请列表 ───
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
                    Expanded(
                      child: Text(app['workerName'] ?? '未知工人',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('電話：${app['workerPhone'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('地盤：${app['siteName'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('每日薪酬：HK\$ ${app['dailyWage'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (app['contractAttachment'] != null) ...[
                  const SizedBox(height: 8),
                  _buildAttachmentLink(app['contractAttachment']),
                ],
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(app),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('審核'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 更换地盘申请列表 ───
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
                    Expanded(
                      child: Text(req['workerName'] ?? '未知工人',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('電話：${req['workerPhone'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('原工地：${req['fromSiteName'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('目標工地：${req['toSiteName'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('每日薪酬：HK\$ ${req['dailyWage'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (req['reason'] != null && req['reason'].toString().isNotEmpty)
                  Text('更換原因：${req['reason']}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (req['contractAttachment'] != null) ...[
                  const SizedBox(height: 8),
                  _buildAttachmentLink(req['contractAttachment']),
                ],
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showReviewChangeDialog(req),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('審核'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 更换公司申请列表 ───
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
                    Expanded(
                      child: Text(req['workerName'] ?? '未知工人',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('電話：${req['workerPhone'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('原公司：${req['fromCompanyName'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                Text('目標公司：${req['toCompanyName'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (req['reason'] != null && req['reason'].toString().isNotEmpty)
                  Text('更換原因：${req['reason']}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showReviewCompanyChangeDialog(req),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('審核'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('申請審核'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: '入盤申請'),
            Tab(text: '更換地盤'),
            Tab(text: '更換公司'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppList(),
          _buildChangeList(),
          _buildCompanyChangeList(),
        ],
      ),
    );
  }
}
