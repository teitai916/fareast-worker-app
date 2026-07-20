/// 安全考核评分项 — 统一配置（唯一维护入口）
/// 修改评分项文字只需改此文件
import 'package:flutter/material.dart';

class SafetyScoreConfig {
  SafetyScoreConfig._();

  /// 评分项总数
  static const int itemCount = 22;

  /// 满分 = 项数 × 10
  static const int maxScore = itemCount * 10;

  // ===== 评分档位颜色 =====
  static const Color tierFully = Color(0xFF4CAF50);    // Fully supporting 9-10 → 绿色
  static const Color tierSupporting = Color(0xFFFFA726); // Supporting 6-8 → 橙色
  static const Color tierNot = Color(0xFFEF5350);        // Not supporting 0-5 → 红色

  /// 根据分值返回对应颜色
  static Color scoreColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 9) return tierFully;
    if (score >= 6) return tierSupporting;
    return tierNot;
  }

  /// 类别分组（按序号 1-based）
  static const Map<String, List<int>> categories = {
    '安全投放資源表現': [1, 2, 3, 4, 5, 6, 7, 8],
    '地盤實地安環表現': [9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
    '安全表現': [19, 20, 21, 22],
  };

  /// 评分项序号 → 中文名称
  static const Map<int, String> names = {
    1: '管理层安全态度',
    2: '具備足夠能力的安全人員',
    3: '提供安全訓練、指示及監督',
    4: '地盤安全設施之提供及維持',
    5: '合作性',
    6: '提供予屬下員工及使用個人保護裝置',
    7: '安全意外率',
    8: '安全表現',
    9: '提供適當安装方法/程序, 或專業分判施工方案',
    10: '聘請安全督導員作為安全代表，跟進地盤事項',
    11: '使用的起重機械/起重裝置持有有效的證書及沒有違反安全操作守則',
    12: '高空工作',
    13: '個人防護裝備使用情況',
    14: '施工/物料擺放位置整潔',
    15: '依照施工方案進行工序',
    16: '改善態度',
    17: '參與早會及安全施工程序會議',
    18: '提供合適的工具(包括梯台及功夫櫈)給予工人使用',
    19: '合約安全守則',
    20: '法例(包括工作守則)',
    21: '工傷事故記錄',
    22: '敦促改善通知書(部份II)/停工通知書 (發出日期)',
  };

  /// 获取评分项名称
  static String name(int index) => names[index] ?? '';

  /// 获取所属类别名
  static String category(int index) {
    for (final entry in categories.entries) {
      if (entry.value.contains(index)) return entry.key;
    }
    return '';
  }

  // ===== 逐项评分指南 =====
  /// 序号 → [{desc, range, color}]，未定义的项返回 null
  static List<Map<String, dynamic>>? guide(int index) => _guides[index];

  static const Map<int, List<Map<String, dynamic>>> _guides = {
    1: [ // 管理层安全态度
      {'desc': 'Fully supporting', 'range': '9-10', 'color': tierFully},
      {'desc': 'Supporting', 'range': '6-8', 'color': tierSupporting},
      {'desc': 'Not supporting', 'range': '0-5', 'color': tierNot},
    ],
    2: [ // 具備足夠能力的安全人員
      {'desc': 'Suitably trained', 'range': '8-10', 'color': tierFully},
      {'desc': 'Training arranged', 'range': '6-7', 'color': tierSupporting},
      {'desc': 'No safety & environmental training', 'range': '0-5', 'color': tierNot},
    ],
    3: [ // 提供安全訓練、指示及監督
      {'desc': 'With good result', 'range': '8-10', 'color': tierFully},
      {'desc': 'Provision given', 'range': '6-7', 'color': tierSupporting},
      {'desc': 'No provision', 'range': '0-5', 'color': tierNot},
    ],
    4: [ // 地盤安全設施之提供及維持
      {'desc': 'Pro-active', 'range': '8-10', 'color': tierFully},
      {'desc': 'Provision given', 'range': '6-7', 'color': tierSupporting},
      {'desc': 'No provision', 'range': '0-5', 'color': tierNot},
    ],
    5: [ // 合作性
      {'desc': 'Co-operating actively', 'range': '8-10', 'color': tierFully},
      {'desc': 'Co-operating', 'range': '6-7', 'color': tierSupporting},
      {'desc': 'Not co-operating', 'range': '0-5', 'color': tierNot},
    ],
    6: [ // 提供予屬下員工及使用個人保護裝置
      {'desc': 'Always use at own will', 'range': '9-10', 'color': tierFully},
      {'desc': 'In use most of the time', 'range': '6-8', 'color': tierSupporting},
      {'desc': 'Always not in use', 'range': '0-5', 'color': tierNot},
    ],
    7: [ // 安全意外率
      {'desc': '0% → 10 分', 'range': '10', 'color': tierFully},
      {'desc': '每 1% 扣 1 分', 'range': '9-0', 'color': tierSupporting},
    ],
    8: [ // 安全表現
      {'desc': 'Never violate safety rules', 'range': '10', 'color': tierFully},
      {'desc': 'Seldom violate safety rules', 'range': '6-9', 'color': tierSupporting},
      {'desc': 'Always violate safety rules', 'range': '0-5', 'color': tierNot},
    ],
    16: [ // 改善態度
      {'desc': '勸喻後立即改善', 'range': '7-10', 'color': tierFully},
      {'desc': '勸喻後一天內改善', 'range': '4-6', 'color': tierSupporting},
      {'desc': '態度毫不積極', 'range': '1-3', 'color': tierNot},
    ],
    17: [ // 參與早會及安全施工程序會議
      {'desc': '早會出席率高於 70%', 'range': '7-10', 'color': tierFully},
      {'desc': '早會出席率 50%-70%', 'range': '4-6', 'color': tierSupporting},
      {'desc': '早會出席率低於 50%', 'range': '1-3', 'color': tierNot},
    ],
    19: [ // 合約安全守則
      {'desc': '沒有收到警告/罰款信', 'range': '7-10', 'color': tierFully},
      {'desc': '1-2 封警告/罰款信', 'range': '4-6', 'color': tierSupporting},
      {'desc': '3 封或以上的警告/罰款信', 'range': '1-3', 'color': tierNot},
    ],
    20: [ // 法例(包括工作守則)
      {'desc': '沒有檢控', 'range': '10', 'color': tierFully},
      {'desc': '1 宗檢控或以上', 'range': '0', 'color': tierNot},
    ],
    21: [ // 工傷事故記錄
      {'desc': '沒有工傷記錄', 'range': '10', 'color': tierFully},
      {'desc': '1 宗', 'range': '5', 'color': tierSupporting},
      {'desc': '3 宗或以上工傷記錄', 'range': '0', 'color': tierNot},
    ],
    22: [ // 敦促改善通知書(部份II)/停工通知書
      {'desc': '沒有收到政府文件', 'range': '10', 'color': tierFully},
      {'desc': '1-2 封', 'range': '5', 'color': tierSupporting},
      {'desc': '3 封或以上', 'range': '0', 'color': tierNot},
      {'desc': '1 封停工令', 'range': '0', 'color': tierNot},
    ],
  };

  /// 构建评分请求 body（序号 → 值）
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
      ...{for (final i in names.keys) 'score$i': scores[i]},
      'remarks': remarks,
    };
    return body;
  }
}
