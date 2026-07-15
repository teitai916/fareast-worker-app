import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/contractor_safety_evaluation.dart';
import 'package:fareast_worker_app/models/user_role.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 评分详情 + 审批操作页
class EvaluationDetailPage extends StatefulWidget {
  final int evaluationId;

  const EvaluationDetailPage({super.key, required this.evaluationId});

  @override
  State<EvaluationDetailPage> createState() => _EvaluationDetailPageState();
}

class _EvaluationDetailPageState extends State<EvaluationDetailPage> {
  final _api = ApiService();
  ContractorSafetyEvaluation? _evaluation;
  bool _loading = true;
  String _actionLoading = '';

  // 审批人选择
  List<Map<String, dynamic>> _approvers = [];
  int? _selectedApprover;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getEvaluationDetail(widget.evaluationId);
      setState(() {
        _evaluation = ContractorSafetyEvaluation.fromJson(data);
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

  Future<void> _submit() async {
    if (_selectedApprover == null) {
      _showSnackBar('請選擇審批人');
      return;
    }
    setState(() => _actionLoading = 'submit');
    try {
      await _api.submitEvaluation(widget.evaluationId, _selectedApprover!);
      _showSnackBar('提交成功');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('提交失敗: $e', true);
    } finally {
      setState(() => _actionLoading = '');
    }
  }

  Future<void> _withdraw() async {
    setState(() => _actionLoading = 'withdraw');
    try {
      await _api.withdrawEvaluation(widget.evaluationId);
      _showSnackBar('已撤回');
      _loadData();
    } catch (e) {
      _showSnackBar('撤回失敗: $e', true);
    } finally {
      setState(() => _actionLoading = '');
    }
  }

  Future<void> _approve() async {
    setState(() => _actionLoading = 'approve');
    try {
      await _api.approveEvaluation(widget.evaluationId);
      _showSnackBar('審批通過');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('操作失敗: $e', true);
    } finally {
      setState(() => _actionLoading = '');
    }
  }

  Future<void> _reject() async {
    final comment = await _showCommentDialog('駁回原因');
    if (comment == null) return;
    setState(() => _actionLoading = 'reject');
    try {
      await _api.rejectEvaluation(widget.evaluationId, comment: comment);
      _showSnackBar('已駁回');
      _loadData();
    } catch (e) {
      _showSnackBar('操作失敗: $e', true);
    } finally {
      setState(() => _actionLoading = '');
    }
  }

  Future<void> _notify() async {
    setState(() => _actionLoading = 'notify');
    try {
      await _api.notifyEvaluation(widget.evaluationId);
      _showSnackBar('已通知');
      _loadData();
    } catch (e) {
      _showSnackBar('通知失敗: $e', true);
    } finally {
      setState(() => _actionLoading = '');
    }
  }

  Future<void> _loadApprovers() async {
    try {
      final data = await _api.getApprovers();
      setState(() => _approvers = data);
    } catch (_) {}
  }

  Future<String?> _showCommentDialog(String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: '可選'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('確定')),
        ],
      ),
    );
  }

  Future<void> _showApproverPicker() async {
    if (_approvers.isEmpty) await _loadApprovers();
    if (_approvers.isEmpty) {
      _showSnackBar('暫無可選審批人');
      return;
    }

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('選擇審批人'),
        children: _approvers.map((a) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, a['id'] as int),
          child: Text('${a['name']} (${a['role']})'),
        )).toList(),
      ),
    );

    if (result != null) {
      setState(() => _selectedApprover = result);
      _submit();
    }
  }

  void _showSnackBar(String msg, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? AppTheme.errorColor : Colors.green),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final userRole = UserRole.fromValue(TokenManager.currentUser?.role ?? '');
    final e = _evaluation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('評分詳情'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : e == null
              ? const Center(child: Text('暫無數據'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 基本信息
                      _infoRow('地盤', e.siteName ?? '-'),
                      _infoRow('分判商', e.companyName ?? '-'),
                      _infoRow('行業', e.tradeOfWork ?? '-'),
                      _infoRow('評估期', '${e.periodYear}年第${e.periodQuarter}季度'),
                      _infoRow('狀態', e.statusLabel),
                      _infoRow('填報人', e.submittedByName ?? '-'),
                      _infoRow('審批人', e.assignedToName ?? '-'),
                      if (e.approvedByName != null) _infoRow('審批通過', e.approvedByName!),
                      if (e.approvalComment != null && e.approvalComment!.isNotEmpty)
                        _infoRow('審批意見', e.approvalComment!),

                      const Divider(height: 32),

                      // 21项评分（按类别分组）
                      if (e.scores.isNotEmpty) ...[
                        const Text('評分明細', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ..._buildScoreDetails(e.scores),
                      ],

                      const Divider(height: 32),

                      // 统计
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statBox('總分', '${e.totalScore ?? 0} / 210', AppTheme.primaryColor),
                          _statBox('百分比', '${e.percentage?.toStringAsFixed(1) ?? "0"}%',
                              _colorForPercentage(e.percentage ?? 0)),
                          _statBox('等級', e.nonCompliantLabel, _colorForLevel(e.nonCompliantLevel ?? 'NONE')),
                        ],
                      ),

                      if (e.remarks != null && e.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _infoRow('備註', e.remarks!),
                      ],

                      const SizedBox(height: 24),

                      // ===== 操作按钮 =====
                      if (_actionLoading.isNotEmpty)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        // 安全人员：草稿状态 → 提交审核
                        if (e.isDraft && userRole == UserRole.safetyOfficer && e.submittedBy == TokenManager.currentUser?.id) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _showApproverPicker,
                              icon: const Icon(Icons.send),
                              label: const Text('提交審核'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () async {
                                await Navigator.pushNamed(context, '/safety/evaluation-form',
                                    arguments: {'id': e.id, 'existing': e});
                                _loadData();
                              },
                              child: const Text('編輯草稿'),
                            ),
                          ),
                        ],

                        // 安全人员：已提交状态 → 撤回
                        if (e.isSubmitted && userRole == UserRole.safetyOfficer && e.submittedBy == TokenManager.currentUser?.id)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _withdraw,
                              icon: const Icon(Icons.undo),
                              label: const Text('撤回審核'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                            ),
                          ),

                        // 审批人：待审批 → 通过/驳回
                        if (e.isSubmitted && e.assignedTo == TokenManager.currentUser?.id) ...[
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _approve,
                                    icon: const Icon(Icons.check),
                                    label: const Text('通過'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _reject,
                                    icon: const Icon(Icons.close),
                                    label: const Text('駁回'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // 已通过 → 知会
                        if (e.isApproved && userRole.isInternalStaff)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _notify,
                              icon: const Icon(Icons.notifications),
                              label: const Text('知會分判商及相關人員'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            ),
                          ),
                      ],

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
    );
  }

  /// 按类别分组显示评分明细
  List<Widget> _buildScoreDetails(Map<String, int?> scores) {
    const categories = {
      '安全投放資源表現': [
        '管理层安全态度', '具備足夠能力的安全人員', '提供安全訓練、指示及監督',
        '地盤安全設施之提供及維持', '合作性', '提供予屬下員工及使用個人保護裝置',
        '安全意外率', '安全表現',
      ],
      '地盤實地安環表現': [
        '提供施工方案及風險評估', '聘請安全督導員', '起重機械/裝置證書',
        '高空工作', '個人防護裝備使用情況', '施工/物料擺放位置整潔',
        '依照施工方案進行工序', '改善態度', '參與早會及安全施工程序會議',
        '提供合適的工具',
      ],
      '安全表現': [
        '合約安全守則', '法例(包括工作守則)', '工傷事故記錄',
      ],
    };

    final List<Widget> widgets = [];
    for (final entry in categories.entries) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
      ));
      for (final key in entry.value) {
        final value = scores[key];
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(key, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary), softWrap: true),
              ),
              const SizedBox(width: 8),
              Text(
                value != null ? '$value / 10' : '-',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: value != null ? AppTheme.textPrimary : AppTheme.textHint),
              ),
            ],
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Color _colorForPercentage(double pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'WARNING': return Colors.orange;
      case 'SEVERE': return Colors.red;
      default: return Colors.green;
    }
  }
}
