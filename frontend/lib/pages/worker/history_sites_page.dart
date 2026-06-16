import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/pages/worker/site_apply_page.dart';
import 'package:fareast_worker_app/pages/worker/change_site_page.dart';

class HistorySitesPage extends StatefulWidget {
  const HistorySitesPage({super.key});

  @override
  State<HistorySitesPage> createState() => _HistorySitesPageState();
}

class _HistorySitesPageState extends State<HistorySitesPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  
  // 申请地盘历史记录
  List<dynamic> _applications = [];
  // 更换地盘历史记录
  List<dynamic> _changeRequests = [];
  
  // 合并后的历史记录
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      // 获取申请地盘历史记录
      final applications = await _api.getMyApplications();
      
      // 获取更换地盘历史记录
      final changeRequests = await _api.getMyChangeRequests();
      
      if (!mounted) return;
      
      // 合并历史记录
      final history = <Map<String, dynamic>>[];
      
      // 添加申请地盘记录
      for (final app in applications) {
        history.add({
          'type': 'apply',
          'id': app['id'],
          'siteId': app['siteId'],
          'companyId': app['companyId'],
          'status': app['status'],
          'createdAt': app['createdAt'],
          'data': app,
        });
      }
      
      // 添加更换地盘记录
      for (final req in changeRequests) {
        history.add({
          'type': 'change',
          'id': req['id'],
          'fromSiteId': req['fromSiteId'],
          'toSiteId': req['toSiteId'],
          'companyId': req['companyId'],
          'status': req['status'],
          'requestedAt': req['requestedAt'],
          'processedAt': req['processedAt'],
          'data': req,
        });
      }
      
      // 按时间倒序排序
      history.sort((a, b) {
        final aTime = a.containsKey('createdAt') ? a['createdAt'] : a['requestedAt'];
        final bTime = b.containsKey('createdAt') ? b['createdAt'] : b['requestedAt'];
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // 倒序
      });
      
      setState(() {
        _applications = applications;
        _changeRequests = changeRequests;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歷史記錄'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history, size: 64, color: AppTheme.textHint),
                          const SizedBox(height: 16),
                          const Text('暫無歷史記錄', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          '申請與更換記錄',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ..._history.map((h) => _buildHistoryItem(h)),
                      ],
                    ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    final type = h['type'] as String;
    
    if (type == 'apply') {
      return _buildApplicationItem(h);
    } else {
      return _buildChangeRequestItem(h);
    }
  }

  Widget _buildApplicationItem(Map<String, dynamic> h) {
    final data = h['data'] as Map<String, dynamic>;
    final status = data['status'] as String;
    final siteName = data['siteName'] as String? ?? '未知地盤';
    final createdAt = data['createdAt'] as String?;
    
    // 状态显示
    String statusText;
    Color statusColor;
    if (status == 'PENDING') {
      statusText = '審核中';
      statusColor = AppTheme.warningColor;
    } else if (status == 'APPROVED') {
      statusText = '已批准';
      statusColor = AppTheme.successColor;
    } else if (status == 'REJECTED') {
      statusText = '已拒絕';
      statusColor = AppTheme.errorColor;
    } else {
      statusText = status;
      statusColor = AppTheme.textHint;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_location, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('申請加入地盤', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(siteName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
                ),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 12),
              Text('申請時間: ${_formatDateTime(createdAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChangeRequestItem(Map<String, dynamic> h) {
    final data = h['data'] as Map<String, dynamic>;
    final status = data['status'] as String;
    final fromSiteName = data['fromSiteName'] as String? ?? '無';
    final toSiteName = data['toSiteName'] as String? ?? '未知地盤';
    final requestedAt = data['requestedAt'] as String?;
    final processedAt = data['processedAt'] as String?;
    
    // 状态显示
    String statusText;
    Color statusColor;
    if (status == 'PENDING') {
      statusText = '審核中';
      statusColor = AppTheme.warningColor;
    } else if (status == 'APPROVED') {
      statusText = '已批准';
      statusColor = AppTheme.successColor;
    } else if (status == 'REJECTED') {
      statusText = '已拒絕';
      statusColor = AppTheme.errorColor;
    } else {
      statusText = status;
      statusColor = AppTheme.textHint;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.swap_horiz, color: AppTheme.infoColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('更換地盤', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('從 $fromSiteName 到 $toSiteName', 
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (requestedAt != null) ...[
              Text('申請時間: ${_formatDateTime(requestedAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
            if (processedAt != null) ...[
              const SizedBox(height: 2),
              Text('處理時間: ${_formatDateTime(processedAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  // 格式化時間：2026年06月08日 16:43:44
  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}年${_pad(dt.month)}月${_pad(dt.day)}日 ${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
    } catch (e) {
      return isoString;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
