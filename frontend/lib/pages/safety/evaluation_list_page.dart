import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/contractor_safety_evaluation.dart';
import 'package:fareast_worker_app/models/user_role.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 安全考核评分列表页
class EvaluationListPage extends StatefulWidget {
  const EvaluationListPage({super.key});

  @override
  State<EvaluationListPage> createState() => _EvaluationListPageState();
}

class _EvaluationListPageState extends State<EvaluationListPage> {
  final _api = ApiService();
  List<ContractorSafetyEvaluation> _evaluations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getEvaluations();
      setState(() {
        _evaluations = data.map((e) => ContractorSafetyEvaluation.fromJson(e)).toList();
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
    final userRole = UserRole.fromValue(TokenManager.currentUser?.role ?? '');
    final bool canCreate = userRole == UserRole.safetyOfficer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('安全考核評分'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _evaluations.isEmpty
              ? const Center(child: Text('暫無評分記錄', style: TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _evaluations.length,
                    itemBuilder: (context, index) => _buildCard(_evaluations[index]),
                  ),
                ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/safety/evaluation-form');
                _loadData();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCard(ContractorSafetyEvaluation e) {
    Color statusColor;
    switch (e.status) {
      case 'DRAFT':
        statusColor = Colors.grey;
        break;
      case 'SUBMITTED':
        statusColor = Colors.orange;
        break;
      case 'APPROVED':
        statusColor = Colors.blue;
        break;
      case 'NOTIFIED':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
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
                  Expanded(
                    child: Text(
                      e.siteName ?? '未知地盤',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(e.statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '分判商: ${e.companyName ?? '未知'}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${e.periodYear}年第${e.periodQuarter}季度  ·  ${e.tradeOfWork ?? ""}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
              ),
              if (e.percentage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildScoreBadge(e),
                    const Spacer(),
                    if (e.submittedByName != null)
                      Text('填報: ${e.submittedByName}', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge(ContractorSafetyEvaluation e) {
    Color color;
    if (e.percentage! >= 80) {
      color = Colors.green;
    } else if (e.percentage! >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${e.percentage!.toStringAsFixed(1)}%  ${e.nonCompliantLabel}',
        style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
