/// 通用考核評分配置 — 從 API 動態加載
/// 調用 SafetyScoreConfig.init('SAFETY_2025') 初始化後使用
import 'package:flutter/material.dart';
import 'package:fareast_worker_app/services/api_service.dart';
import 'package:fareast_worker_app/models/evaluation_score_item_model.dart';

class SafetyScoreConfig {
  SafetyScoreConfig._();

  // ===== 檔位顏色 =====
  static const Color tierFully = Color(0xFF4CAF50);
  static const Color tierSupporting = Color(0xFFFFA726);
  static const Color tierNot = Color(0xFFEF5350);

  /// 根據分值返回對應顏色
  static Color scoreColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 9) return tierFully;
    if (score >= 6) return tierSupporting;
    return tierNot;
  }

  // ===== 模板 & 評分項數據（init() 後可用） =====
  static String _templateCode = '';
  static String _templateName = '';
  static int _maxScorePerItem = 10;
  static int _itemCount = 0;
  static int _maxScore = 0;
  static final List<EvaluationScoreItemModel> _items = [];
  static bool _initialized = false;

  static String get templateCode => _templateCode;
  static String get templateName => _templateName;
  static int get maxScorePerItem => _maxScorePerItem;
  static int get itemCount => _itemCount;
  static int get maxScore => _maxScore;
  static bool get initialized => _initialized;
  static List<EvaluationScoreItemModel> get items => List.unmodifiable(_items);

  /// 加載模板數據（調用一次即緩存）
  static Future<void> init(String templateCode, {ApiService? api}) async {
    if (_initialized && _templateCode == templateCode) return;
    try {
      final service = api ?? ApiService();
      final data = await service.getEvaluationTemplateItems(templateCode);

      final template = data['template'] as Map<String, dynamic>;
      _templateCode = template['code'] as String;
      _templateName = template['name'] as String;
      _maxScorePerItem = (template['maxScorePerItem'] as num).toInt();
      _itemCount = (template['itemCount'] as num).toInt();
      _maxScore = (template['maxScore'] as num).toInt();

      _items.clear();
      for (final it in (data['items'] as List)) {
        _items.add(EvaluationScoreItemModel.fromJson(it as Map<String, dynamic>));
      }
      _initialized = true;
    } catch (e) {
      debugPrint('SafetyScoreConfig.init API 失败: $e，使用本地默认数据');
      _loadDefaultItems(templateCode);
      _initialized = true;
    }
  }

  static void _loadDefaultItems(String templateCode) {
    if (templateCode != 'SAFETY_2025') return;
    _templateCode = 'SAFETY_2025';
    _templateName = '分判商安全考核評分';
    _maxScorePerItem = 10;
    _itemCount = 22;
    _maxScore = 220;
    _items.clear();
    _items.addAll([
      const EvaluationScoreItemModel(scoreIndex: 1,  category: '安全投放資源表現', nameZh: '管理层安全态度', sortOrder: 1),
      const EvaluationScoreItemModel(scoreIndex: 2,  category: '安全投放資源表現', nameZh: '具備足夠能力的安全人員', sortOrder: 2),
      const EvaluationScoreItemModel(scoreIndex: 3,  category: '安全投放資源表現', nameZh: '提供安全訓練、指示及監督', sortOrder: 3),
      const EvaluationScoreItemModel(scoreIndex: 4,  category: '安全投放資源表現', nameZh: '地盤安全設施之提供及維持', sortOrder: 4),
      const EvaluationScoreItemModel(scoreIndex: 5,  category: '安全投放資源表現', nameZh: '合作性', sortOrder: 5),
      const EvaluationScoreItemModel(scoreIndex: 6,  category: '安全投放資源表現', nameZh: '提供予屬下員工及使用個人保護裝置', sortOrder: 6),
      const EvaluationScoreItemModel(scoreIndex: 7,  category: '安全投放資源表現', nameZh: '安全意外率', sortOrder: 7),
      const EvaluationScoreItemModel(scoreIndex: 8,  category: '安全投放資源表現', nameZh: '安全表現', sortOrder: 8),
      const EvaluationScoreItemModel(scoreIndex: 9,  category: '地盤實地安環表現', nameZh: '提供適當安装方法/程序, 或專業分判施工方案', sortOrder: 1),
      const EvaluationScoreItemModel(scoreIndex: 10, category: '地盤實地安環表現', nameZh: '聘請安全督導員作為安全代表，跟進地盤事項', sortOrder: 2),
      const EvaluationScoreItemModel(scoreIndex: 11, category: '地盤實地安環表現', nameZh: '使用的起重機械/起重裝置持有有效的證書及沒有違反安全操作守則', sortOrder: 3),
      const EvaluationScoreItemModel(scoreIndex: 12, category: '地盤實地安環表現', nameZh: '高空工作', sortOrder: 4),
      const EvaluationScoreItemModel(scoreIndex: 13, category: '地盤實地安環表現', nameZh: '個人防護裝備使用情況', sortOrder: 5),
      const EvaluationScoreItemModel(scoreIndex: 14, category: '地盤實地安環表現', nameZh: '施工/物料擺放位置整潔', sortOrder: 6),
      const EvaluationScoreItemModel(scoreIndex: 15, category: '地盤實地安環表現', nameZh: '依照施工方案進行工序', sortOrder: 7),
      const EvaluationScoreItemModel(scoreIndex: 16, category: '地盤實地安環表現', nameZh: '改善態度', sortOrder: 8),
      const EvaluationScoreItemModel(scoreIndex: 17, category: '地盤實地安環表現', nameZh: '參與早會及安全施工程序會議', sortOrder: 9),
      const EvaluationScoreItemModel(scoreIndex: 18, category: '地盤實地安環表現', nameZh: '提供合適的工具(包括梯台及功夫櫈)給予工人使用', sortOrder: 10),
      const EvaluationScoreItemModel(scoreIndex: 19, category: '安全表現', nameZh: '合約安全守則', sortOrder: 1),
      const EvaluationScoreItemModel(scoreIndex: 20, category: '安全表現', nameZh: '法例(包括工作守則)', sortOrder: 2),
      const EvaluationScoreItemModel(scoreIndex: 21, category: '安全表現', nameZh: '工傷事故記錄', sortOrder: 3),
      const EvaluationScoreItemModel(scoreIndex: 22, category: '安全表現', nameZh: '敦促改善通知書(部份II)/停工通知書 (發出日期)', sortOrder: 4),
    ]);
  }

  /// 獲取評分項名稱
  static String name(int index) {
    for (final it in _items) {
      if (it.scoreIndex == index) return it.nameZh;
    }
    return '';
  }

  /// 獲取所屬類別名
  static String category(int index) {
    for (final it in _items) {
      if (it.scoreIndex == index) return it.category;
    }
    return '';
  }

  /// 獲取類別分組 {category → [scoreIndex]}
  static Map<String, List<int>> get categories {
    final map = <String, List<int>>{};
    for (final it in _items) {
      map.putIfAbsent(it.category, () => []).add(it.scoreIndex);
    }
    return map;
  }

  /// 獲取評分指南
  static List<Map<String, dynamic>>? guide(int index) {
    for (final it in _items) {
      if (it.scoreIndex == index) {
        final guides = <Map<String, dynamic>>[];
        for (final g in it.guides) {
          guides.add({
            'desc': g['desc'],
            'range': g['range'],
            'color': _guideColor(guides.length),
          });
        }
        return guides.isNotEmpty ? guides : null;
      }
    }
    return null;
  }

  static Color _guideColor(int index) {
    switch (index) {
      case 0: return tierFully;
      case 1: return tierSupporting;
      default: return tierNot;
    }
  }

  /// 構建提交 body
  static Map<String, dynamic> buildBody(Map<int, int?> scores, {
    int? siteId,
    int? companyId,
    String? tradeOfWork,
    required int periodYear,
    required int periodQuarter,
    String? remarks,
  }) {
    final body = <String, dynamic>{
      'siteId': siteId,
      'companyId': companyId,
      'tradeOfWork': tradeOfWork,
      'period': 'QUARTERLY',
      'periodYear': periodYear,
      'periodQuarter': periodQuarter,
      ...{for (final i in _items) 'score${i.scoreIndex}': scores[i.scoreIndex]},
      'remarks': remarks,
    };
    return body;
  }
}
