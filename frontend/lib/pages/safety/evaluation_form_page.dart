import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/safety_score_config.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/contractor_safety_evaluation.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 安全考核评分表单页
class EvaluationFormPage extends StatefulWidget {
  final int? evaluationId;
  final ContractorSafetyEvaluation? existing;

  const EvaluationFormPage({super.key, this.evaluationId, this.existing});

  @override
  State<EvaluationFormPage> createState() => _EvaluationFormPageState();
}

class _EvaluationFormPageState extends State<EvaluationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  bool _loading = false;

  int? _siteId;
  int? _companyId;
  String? _tradeOfWork;
  int? _periodYear = DateTime.now().year;
  int? _periodQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
  String _remarks = '';

  /// 序号 → 分值
  final Map<int, int?> _scores = {for (final i in SafetyScoreConfig.names.keys) i: null};
  bool _isEditing = false;

  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _companies = [];
  bool _loadingOptions = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.evaluationId != null;
    if (widget.existing != null) {
      final e = widget.existing!;
      _siteId = e.siteId;
      _companyId = e.companyId;
      _tradeOfWork = e.tradeOfWork;
      _periodYear = e.periodYear ?? DateTime.now().year;
      _periodQuarter = e.periodQuarter ?? ((DateTime.now().month - 1) ~/ 3) + 1;
      _remarks = e.remarks ?? '';
      for (final i in SafetyScoreConfig.names.keys) {
        _scores[i] = e.scores[SafetyScoreConfig.name(i)];
      }
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final sites = await _api.getInternalSites();
      final companies = await _api.getInternalCompanies();
      if (mounted) setState(() { _sites = sites; _companies = companies; _loadingOptions = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_siteId == null) { _showError('請選擇地盤'); return; }
    if (_companyId == null) { _showError('請選擇分判商'); return; }

    setState(() => _loading = true);
    try {
      final body = SafetyScoreConfig.buildBody(_scores,
        siteId: _siteId, companyId: _companyId, tradeOfWork: _tradeOfWork,
        periodYear: _periodYear!, periodQuarter: _periodQuarter!, remarks: _remarks,
      );
      if (_isEditing && widget.evaluationId != null) {
        await _api.updateEvaluation(widget.evaluationId!, body);
      } else {
        await _api.createEvaluation(body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _showError('保存失敗: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯評分' : '新建評分'),
        backgroundColor: Colors.transparent, foregroundColor: AppTheme.textPrimary, elevation: 0,
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  _sectionTitle('基本信息'),

                  DropdownButtonFormField<int?>(
                    value: _siteId,
                    decoration: const InputDecoration(labelText: '地盤', border: OutlineInputBorder()),
                    items: _sites.map((s) => DropdownMenuItem<int?>(value: s['id'] as int, child: Text(s['name'] as String? ?? '', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _siteId = v),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<int?>(
                    value: _companyId,
                    decoration: const InputDecoration(labelText: '分判商', border: OutlineInputBorder()),
                    items: _companies.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['name'] as String? ?? '', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _companyId = v),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    initialValue: _tradeOfWork,
                    decoration: const InputDecoration(labelText: '行業', hintText: '如：安裝、測試、供應及安裝', border: OutlineInputBorder()),
                    onChanged: (v) => _tradeOfWork = v,
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _periodYear,
                          decoration: const InputDecoration(labelText: '年份', border: OutlineInputBorder()),
                          items: List.generate(5, (i) { final y = DateTime.now().year - 2 + i; return DropdownMenuItem(value: y, child: Text('$y 年')); }),
                          onChanged: (v) => setState(() => _periodYear = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _periodQuarter,
                          decoration: const InputDecoration(labelText: '季度', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('一季度')), DropdownMenuItem(value: 2, child: Text('二季度')),
                            DropdownMenuItem(value: 3, child: Text('三季度')), DropdownMenuItem(value: 4, child: Text('四季度')),
                          ],
                          onChanged: (v) => setState(() => _periodQuarter = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ..._buildScoreFields(),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _remarks,
                    decoration: const InputDecoration(labelText: '備註', border: OutlineInputBorder()),
                    maxLines: 2, onChanged: (v) => _remarks = v,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isEditing ? '保存修改' : '保存草稿', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }

  void _showGuideDialog(String label, List<Map<String, dynamic>> guide) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: guide.map((t) {
            final color = t['color'] as Color;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(t['desc'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
                  const Spacer(),
                  Text('(${t['range']})', style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉'))],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
  );

  List<Widget> _buildScoreFields() {
    final widgets = <Widget>[];
    String? lastCategory;
    for (final i in SafetyScoreConfig.names.keys) {
      final cat = SafetyScoreConfig.category(i);
      if (cat != lastCategory) {
        lastCategory = cat;
        widgets.add(_sectionTitle(cat));
        widgets.add(const SizedBox(height: 8));
      }
      final name = SafetyScoreConfig.name(i);
      widgets.add(_scoreField(i, name));
      widgets.add(const SizedBox(height: 4));
    }
    return widgets;
  }

  Widget _scoreField(int index, String label) {
    final currentVal = _scores[index];
    final guide = SafetyScoreConfig.guide(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$index', style: const TextStyle(color: AppTheme.textHint, fontSize: 13))),
          const SizedBox(width: 8),
          if (currentVal != null)
            Container(width: 4, height: 32, decoration: BoxDecoration(color: SafetyScoreConfig.scoreColor(currentVal), borderRadius: BorderRadius.circular(2)))
          else
            const SizedBox(width: 4),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                if (guide != null) ...[
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: () => _showGuideDialog(label, guide),
                    child: const Icon(Icons.info_outline, size: 14, color: AppTheme.textHint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: DropdownButtonFormField<int?>(
              value: currentVal,
              decoration: InputDecoration(
                hintText: '必填',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
                enabledBorder: currentVal != null
                    ? OutlineInputBorder(borderSide: BorderSide(color: SafetyScoreConfig.scoreColor(currentVal), width: 1.5))
                    : const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('-')),
                for (int v = 0; v <= 10; v++)
                  DropdownMenuItem(
                    value: v,
                    child: Text('$v', style: TextStyle(color: SafetyScoreConfig.scoreColor(v), fontWeight: FontWeight.w600)),
                  ),
              ],
              onChanged: (v) => setState(() => _scores[index] = v),
              validator: (v) => v == null ? '必填' : null,
            ),
          ),
        ],
      ),
    );
  }
}
