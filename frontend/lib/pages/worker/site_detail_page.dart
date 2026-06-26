import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/pages/worker/site_apply_page.dart';

class SiteDetailPage extends StatefulWidget {
  final int? siteId;
  final String? siteName;
  const SiteDetailPage({super.key, this.siteId, this.siteName});

  @override
  State<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends State<SiteDetailPage> {
  Map<String, dynamic>? _site;
  bool _loading = true;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _loadSiteDetail();
  }

  Future<void> _loadSiteDetail() async {
    setState(() => _loading = true);
    try {
      // 如果能取到地盘列表，找到对应地盘
      final sites = await ApiService().getSites();
      final site = sites.firstWhere(
            (s) => s['id'] == widget.siteId,
        orElse: () => null,
      );
      setState(() => _site = site);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加載地盤信息失敗：${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _applyToSite() async {
    if (widget.siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地盤ID缺失，無法申請')),
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteApplyPage(siteId: widget.siteId!, siteName: widget.siteName ?? _site?['name'] ?? '未知地盘'),
      ),
    );
    if (result == true) {
      setState(() => _hasApplied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final siteName = widget.siteName ?? _site?['name'] ?? '地盤詳情';
    final site = _site;

    return Scaffold(
      appBar: AppBar(title: Text(siteName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 地盘基本信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(siteName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _InfoRow(label: '地盤編號', value: site?['siteNo'] ?? site?['siteNumber'] ?? 'S-2026-001'),
                    _InfoRow(label: '所屬公司', value: site?['companyName'] ?? '遠東建築有限公司'),
                    _InfoRow(label: '地盤地址', value: site?['address'] ?? '九龍九龍灣宏照道38號'),
                    _InfoRow(label: '啟用日期', value: site?['startDate'] ?? site?['createdAt']?.toString().substring(0, 10) ?? '2026-01-15'),
                    _InfoRow(label: '工人數量', value: '${site?['workerCount'] ?? 42}人'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 安全信息
            const Text('安全信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCard('安全分平均', '85', AppTheme.successColor)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard('今日出勤', '${site?['todayAttendance'] ?? 38}人', AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCard('黑名單人數', '${site?['blacklistCount'] ?? 2}人', AppTheme.errorColor)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard('事故次數', '${site?['accidentCount'] ?? 0}次', AppTheme.successColor)),
              ],
            ),
            const SizedBox(height: 32),

            // 申请加入按钮
            if (!_hasApplied)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _applyToSite,
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('申請加入此地盤'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (_hasApplied)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle, color: AppTheme.successColor),
                  label: const Text('已提交申請，待審核', style: TextStyle(color: AppTheme.successColor)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.successColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
