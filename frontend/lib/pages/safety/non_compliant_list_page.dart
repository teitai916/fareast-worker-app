import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/contractor_safety_evaluation.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 不合格分判商清单
class NonCompliantListPage extends StatefulWidget {
  const NonCompliantListPage({super.key});

  @override
  State<NonCompliantListPage> createState() => _NonCompliantListPageState();
}

class _NonCompliantListPageState extends State<NonCompliantListPage> {
  final _api = ApiService();
  List<ContractorSafetyEvaluation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getNonCompliantList();
      setState(() {
        _items = data.map((e) => ContractorSafetyEvaluation.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入失敗: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('不合格分判商清單'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('暫無不合格記錄', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _buildCard(_items[index]),
                  ),
                ),
    );
  }

  Widget _buildCard(ContractorSafetyEvaluation e) {
    Color severityColor;
    IconData icon;
    String label;
    switch (e.nonCompliantLevel) {
      case 'SEVERE':
        severityColor = Colors.red;
        icon = Icons.report;
        label = '約談處分';
        break;
      case 'WARNING':
        severityColor = Colors.orange;
        icon = Icons.warning_amber;
        label = '書面警告';
        break;
      default:
        severityColor = Colors.green;
        icon = Icons.check;
        label = '合格';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.pushNamed(context, '/safety/evaluation-detail', arguments: e.id);
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: severityColor, size: 20),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: severityColor)),
                  const Spacer(),
                  Text(
                    '${e.percentage?.toStringAsFixed(1) ?? "0"}%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: severityColor),
                  ),
                ],
              ),
              const Divider(height: 16),
              _infoRow('地盤', e.siteName ?? '-'),
              _infoRow('分判商', e.companyName ?? '-'),
              _infoRow('評估期', '${e.periodYear}年第${e.periodQuarter}季度'),
              _infoRow('總分', '${e.totalScore ?? 0} / 220'),
              if (e.approvedByName != null) _infoRow('審批人', e.approvedByName!),
              if (e.remarks != null && e.remarks!.isNotEmpty)
                _infoRow('備註', e.remarks!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }
}
