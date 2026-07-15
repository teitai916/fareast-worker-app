import 'package:flutter/material.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/models/contractor_safety_evaluation.dart';
import 'package:fareast_worker_app/services/api_service.dart';

/// 安全考核评分表单页（安全人员填报）
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

  final Map<String, int?> _scores = {};
  bool _isEditing = false;

  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _companies = [];
  bool _loadingOptions = true;

  static const _scoreItems = [
    {'key': '管理层安全态度', 'category': '安全投放資源表現', 'index': 1},
    {'key': '具備足夠能力的安全人員', 'category': '安全投放資源表現', 'index': 2},
    {'key': '提供安全訓練、指示及監督', 'category': '安全投放資源表現', 'index': 3},
    {'key': '地盤安全設施之提供及維持', 'category': '安全投放資源表現', 'index': 4},
    {'key': '合作性', 'category': '安全投放資源表現', 'index': 5},
    {'key': '提供予屬下員工及使用個人保護裝置', 'category': '安全投放資源表現', 'index': 6},
    {'key': '安全意外率', 'category': '安全投放資源表現', 'index': 7},
    {'key': '安全表現', 'category': '安全投放資源表現', 'index': 8},
    {'key': '提供施工方案及風險評估', 'category': '地盤實地安環表現', 'index': 9},
    {'key': '聘請安全督導員', 'category': '地盤實地安環表現', 'index': 10},
    {'key': '起重機械/裝置證書', 'category': '地盤實地安環表現', 'index': 11},
    {'key': '高空工作', 'category': '地盤實地安環表現', 'index': 12},
    {'key': '個人防護裝備使用情況', 'category': '地盤實地安環表現', 'index': 13},
    {'key': '施工/物料擺放位置整潔', 'category': '地盤實地安環表現', 'index': 14},
    {'key': '依照施工方案進行工序', 'category': '地盤實地安環表現', 'index': 15},
    {'key': '改善態度', 'category': '地盤實地安環表現', 'index': 16},
    {'key': '參與早會及安全施工程序會議', 'category': '地盤實地安環表現', 'index': 17},
    {'key': '提供合適的工具', 'category': '地盤實地安環表現', 'index': 18},
    {'key': '合約安全守則', 'category': '安全表現', 'index': 19},
    {'key': '法例(包括工作守則)', 'category': '安全表現', 'index': 20},
    {'key': '工傷事故記錄', 'category': '安全表現', 'index': 21},
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.evaluationId != null;
    for (var item in _scoreItems) {
      _scores[item['key'] as String] = null;
    }
    if (widget.existing != null) {
      final e = widget.existing!;
      _siteId = e.siteId;
      _companyId = e.companyId;
      _tradeOfWork = e.tradeOfWork;
      _periodYear = e.periodYear ?? DateTime.now().year;
      _periodQuarter = e.periodQuarter ?? ((DateTime.now().month - 1) ~/ 3) + 1;
      _remarks = e.remarks ?? '';
      _scores.addAll(e.scores);
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final sites = await _api.getInternalSites();
      final companies = await _api.getInternalCompanies();
      if (mounted) {
        setState(() {
          _sites = sites;
          _companies = companies;
          _loadingOptions = false;
        });
      }
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
      final body = <String, dynamic>{
        'siteId': _siteId,
        'companyId': _companyId,
        'tradeOfWork': _tradeOfWork,
        'period': 'QUARTERLY',
        'periodYear': _periodYear,
        'periodQuarter': _periodQuarter,
        'score1': _scores['管理层安全态度'],
        'score2': _scores['具備足夠能力的安全人員'],
        'score3': _scores['提供安全訓練、指示及監督'],
        'score4': _scores['地盤安全設施之提供及維持'],
        'score5': _scores['合作性'],
        'score6': _scores['提供予屬下員工及使用個人保護裝置'],
        'score7': _scores['安全意外率'],
        'score8': _scores['安全表現'],
        'score9': _scores['提供施工方案及風險評估'],
        'score10': _scores['聘請安全督導員'],
        'score11': _scores['起重機械/裝置證書'],
        'score12': _scores['高空工作'],
        'score13': _scores['個人防護裝備使用情況'],
        'score14': _scores['施工/物料擺放位置整潔'],
        'score15': _scores['依照施工方案進行工序'],
        'score16': _scores['改善態度'],
        'score17': _scores['參與早會及安全施工程序會議'],
        'score18': _scores['提供合適的工具'],
        'score19': _scores['合約安全守則'],
        'score20': _scores['法例(包括工作守則)'],
        'score21': _scores['工傷事故記錄'],
        'remarks': _remarks,
      };

      if (_isEditing && widget.evaluationId != null) {
        await _api.updateEvaluation(widget.evaluationId!, body);
      } else {
        await _api.createEvaluation(body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _showError('保存失敗: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '編輯評分' : '新建評分'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('基本信息'),

                  // 地盘
                  DropdownButtonFormField<int?>(
                    value: _siteId,
                    decoration: const InputDecoration(labelText: '地盤', border: OutlineInputBorder()),
                    items: _sites.map((s) => DropdownMenuItem<int?>(
                      value: s['id'] as int,
                      child: Text(s['name'] as String? ?? '', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _siteId = v),
                  ),
                  const SizedBox(height: 8),

                  // 分判商
                  DropdownButtonFormField<int?>(
                    value: _companyId,
                    decoration: const InputDecoration(labelText: '分判商', border: OutlineInputBorder()),
                    items: _companies.map((c) => DropdownMenuItem<int?>(
                      value: c['id'] as int,
                      child: Text(c['name'] as String? ?? '', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _companyId = v),
                  ),
                  const SizedBox(height: 8),

                  // 行业
                  TextFormField(
                    initialValue: _tradeOfWork,
                    decoration: const InputDecoration(labelText: '行業', hintText: '如：安裝、測試、供應及安裝', border: OutlineInputBorder()),
                    onChanged: (v) => _tradeOfWork = v,
                  ),
                  const SizedBox(height: 8),

                  // 评估期：年份 + 季度
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _periodYear,
                          decoration: const InputDecoration(labelText: '年份', border: OutlineInputBorder()),
                          items: List.generate(5, (i) {
                            final y = DateTime.now().year - 2 + i;
                            return DropdownMenuItem(value: y, child: Text('$y 年'));
                          }),
                          onChanged: (v) => setState(() => _periodYear = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _periodQuarter,
                          decoration: const InputDecoration(labelText: '季度', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('一季度')),
                            DropdownMenuItem(value: 2, child: Text('二季度')),
                            DropdownMenuItem(value: 3, child: Text('三季度')),
                            DropdownMenuItem(value: 4, child: Text('四季度')),
                          ],
                          onChanged: (v) => setState(() => _periodQuarter = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 评分项
                  ..._buildScoreFields(),
                  const SizedBox(height: 16),

                  // 备注
                  TextFormField(
                    initialValue: _remarks,
                    decoration: const InputDecoration(labelText: '備註', border: OutlineInputBorder()),
                    maxLines: 2,
                    onSaved: (v) => _remarks = v ?? '',
                  ),
                  const SizedBox(height: 24),

                  // 保存
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isEditing ? '保存修改' : '保存草稿', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
    );
  }

  List<Widget> _buildScoreFields() {
    final List<Widget> widgets = [];
    String? currentCategory;
    for (final item in _scoreItems) {
      final category = item['category'] as String;
      final key = item['key'] as String;
      final index = item['index'] as int;
      if (category != currentCategory) {
        currentCategory = category;
        widgets.add(_sectionTitle(category));
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(_scoreField(index.toString(), key));
      widgets.add(const SizedBox(height: 4));
    }
    return widgets;
  }

  Widget _scoreField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 13))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(key, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: DropdownButtonFormField<int?>(
              value: _scores[key],
              decoration: const InputDecoration(
                hintText: '必填',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('-', textAlign: TextAlign.center)),
                for (int i = 0; i <= 10; i++)
                  DropdownMenuItem(value: i, child: Text('$i', textAlign: TextAlign.center)),
              ],
              onChanged: (v) => setState(() => _scores[key] = v),
              validator: (v) => v == null ? '必填' : null,
            ),
          ),
        ],
      ),
    );
  }
}
