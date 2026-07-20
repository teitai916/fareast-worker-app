import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:fareast_worker_app/services/api_service.dart';

/// 天气警告提示栏 - 可复用于工人首页和内部人员首页
/// 显示香港天文台的台风/暴雨/酷热/工作暑热警告
class WeatherWarningBar extends StatefulWidget {
  final bool isInternal;
  const WeatherWarningBar({super.key, this.isInternal = false});

  @override
  State<WeatherWarningBar> createState() => _WeatherWarningBarState();
}

class _WeatherWarningBarState extends State<WeatherWarningBar> {
  List<_WarningItem> _warnings = [];
  bool _loading = true;
  bool _expanded = false;

  // 优先级: 台风(1) > 暴雨(2) > 酷热(3) > 雷暴(4) > 其他(5)
  static const Map<String, int> _priority = {
    'WTCSGNL': 1,
    'WRAIN': 2, 'WRAINR': 2, 'WRAINB': 2,
    'WHOT': 3,
    'WTS': 4,
    'WL': 5, 'WFNTSA': 5, 'WFIRE': 5, 'WCOLD': 5, 'WFROST': 5,
  };

  // 从中文信号描述中提取信号号（如 "八號東北" -> 8, "十號" -> 10, "三號" -> 3）
  static int? _chineseSignalNumber(String s) {
    if (s.contains('十')) return 10;
    if (s.contains('九')) return 9;
    if (s.contains('八')) return 8;
    if (s.contains('三')) return 3;
    if (s.contains('一')) return 1;
    return null;
  }

  // 台风信号等级映射
  // 真实 warnsum 中等级不在 name，而在 type（如 "八號東北"/"三號"/"十號"）与 inner code（如 TC8NE/TC10）
  static int _typhoonLevel(Map<String, dynamic> warn) {
    final type = warn['type']?.toString() ?? '';
    final fromType = _chineseSignalNumber(type);
    if (fromType != null) return fromType;
    final code = warn['code']?.toString() ?? '';
    final m = RegExp(r'TC(\d+)').firstMatch(code);
    if (m != null) return int.tryParse(m.group(1)!) ?? 1;
    return 1; // 默认一號
  }

  // 暴雨等级映射
  // 真实 warnsum 中等级在 type（黃色/紅色/黑色）或 inner code 后缀（WRAINA/WRAINR/WRAINB -> A/R/B）
  static int _rainstormLevel(String? type, String? innerCode) {
    final t = type ?? '';
    if (t.contains('黑')) return 3; // 黑色
    if (t.contains('紅')) return 2; // 紅色
    if (t.contains('黃')) return 1; // 黃色
    final c = innerCode ?? '';
    if (c.endsWith('B')) return 3;
    if (c.endsWith('R')) return 2;
    return 1; // 黄色
  }

  // HSWW 等级映射
  static int _hswwLevel(String level) {
    switch (level) {
      case 'BLACK': return 3;
      case 'RED': return 2;
      default: return 1; // AMBER
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    try {
      final data = widget.isInternal
          ? await ApiService().getInternalWeatherWarnings()
          : await ApiService().getWeatherWarnings();
      _parseWarnings(data);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _parseWarnings(Map<String, dynamic> data) {
    final List<_WarningItem> items = [];

    // 1. 解析 warnsum
    try {
      final warnsumStr = data['warnsum'] as String?;
      if (warnsumStr != null && warnsumStr.isNotEmpty && warnsumStr != '{}') {
        final warnsum = jsonDecode(warnsumStr) as Map<String, dynamic>;
        for (final entry in warnsum.entries) {
          final code = entry.key;
          final warn = entry.value as Map<String, dynamic>;
          final actionCode = warn['actionCode']?.toString() ?? '';
          // 跳过已取消的警告
          if (actionCode == 'CANCEL') continue;

          final name = warn['name']?.toString() ?? code;
          // 真正的等级（颜色/信号号）在 type 与 inner code 字段，不在 name
          final type = warn['type']?.toString();
          final innerCode = warn['code']?.toString();
          final issueTime = warn['issueTime']?.toString() ?? '';
          final updateTime = warn['updateTime']?.toString() ?? issueTime;
          final expireTime = warn['expireTime']?.toString();

          final priority = _priority[code] ?? 5;

          // 获取警告等级（颜色/信号号实际在 type 与 inner code 字段）
          int level = 1;
          if (code == 'WTCSGNL') {
            level = _typhoonLevel(warn);
          } else if (code.startsWith('WRAIN')) {
            level = _rainstormLevel(type, innerCode);
          }

          items.add(_WarningItem(
            code: code,
            name: name,
            level: level,
            priority: priority,
            issueTime: issueTime,
            updateTime: updateTime,
            expireTime: expireTime,
            type: type,
          ));
        }
      }
    } catch (_) {}

    // 2. 解析 HSWW（工作暑热警告）
    try {
      final hswwStr = data['hsww'] as String?;
      if (hswwStr != null && hswwStr.isNotEmpty && hswwStr != '{}') {
        final hswwData = jsonDecode(hswwStr) as Map<String, dynamic>;
        final hsww = hswwData['hsww'] as Map<String, dynamic>?;
        if (hsww != null) {
          final actionCode = hsww['actionCode']?.toString() ?? '';
          if (actionCode != 'CANCEL') {
            final warningLevel = hsww['warningLevel']?.toString() ?? 'AMBER';
            final desc = hsww['desc']?.toString() ?? '';
            final issueTime = hsww['issueTime']?.toString() ?? '';

            items.add(_WarningItem(
              code: 'HSWW',
              name: '工作暑熱警告',
              level: _hswwLevel(warningLevel),
              priority: 3, // 与酷热同级
              issueTime: issueTime,
              updateTime: issueTime,
              expireTime: null,
              description: desc,
              warningLevel: warningLevel,
            ));
          }
        }
      }
    } catch (_) {}

    // 按优先级排序
    items.sort((a, b) => a.priority.compareTo(b.priority));

    if (!mounted) return;
    setState(() {
      _warnings = items;
      _loading = false;
    });
  }

  Color _backgroundColor(_WarningItem w) {
    // 黑色级别：暑热黑/暴雨黑/8号+
    if (w.level >= 3 && (w.code == 'HSWW' || w.code.startsWith('WRAIN') || w.code == 'WTCSGNL')) {
      return const Color(0xFF333333);
    }
    // 红色/橙色：暑热红/暴雨红/3号风球
    if (w.level >= 2) {
      return const Color(0xFFFFF3E0);
    }
    // 黄色：暑热黄/暴雨黄/1号风球
    if (w.code == 'WHOT' || w.code == 'WRAIN' || (w.code == 'WTCSGNL' && w.level == 1)) {
      return const Color(0xFFFFF8E1);
    }
    // 蓝色：雷暴/山泥/水浸等
    return const Color(0xFFE3F2FD);
  }

  Color _textColor(_WarningItem w) {
    if (w.level >= 3 && (w.code == 'HSWW' || w.code.startsWith('WRAIN') || w.code == 'WTCSGNL')) {
      return Colors.white;
    }
    if (w.level >= 2) {
      return const Color(0xFFBF360C);
    }
    if (w.code == 'WHOT' || w.code == 'WRAIN' || (w.code == 'WTCSGNL' && w.level == 1)) {
      return const Color(0xFFE65100);
    }
    return const Color(0xFF0D47A1);
  }

  IconData _warningIcon(_WarningItem w) {
    if (w.code == 'WTCSGNL') return Icons.cyclone;
    if (w.code.startsWith('WRAIN')) return Icons.water_drop;
    if (w.code == 'WHOT' || w.code == 'HSWW') return Icons.wb_sunny;
    if (w.code == 'WTS') return Icons.flash_on;
    return Icons.warning_amber;
  }

  String _warningText(_WarningItem w) {
    if (w.code == 'HSWW') {
      final levelStr = {'AMBER': '黃色', 'RED': '紅色', 'BLACK': '黑色'}[w.warningLevel] ?? '';
      return '$levelStr工作暑熱警告 現正生效';
    }
    if (w.code == 'WTCSGNL') {
      // w.type 如 "八號東北" / "三號" / "十號"；缺省时按等级补 "X號"
      final sig = w.type?.isNotEmpty == true ? w.type! : '${w.level}號';
      return '$sig熱帶氣旋警告信號 現正生效';
    }
    if (w.code.startsWith('WRAIN')) {
      // w.type 如 "黃色"/"紅色"/"黑色"，正确显示黃/紅/黑雨
      final color = w.type?.isNotEmpty == true ? w.type! : '';
      return '${color}暴雨警告 現正生效';
    }
    return '${w.name} 現正生效';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _warnings.isEmpty) return const SizedBox.shrink();

    final topWarning = _warnings.first;
    final hasMore = _warnings.length > 1;

    return Column(
      children: [
        // 最高优先级警告
        GestureDetector(
          onTap: hasMore ? () => setState(() => _expanded = !_expanded) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _backgroundColor(topWarning),
              borderRadius: hasMore && _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_warningIcon(topWarning), color: _textColor(topWarning), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _warningText(topWarning),
                        style: TextStyle(
                          color: _textColor(topWarning),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (topWarning.description != null && topWarning.description!.isNotEmpty)
                        Text(
                          topWarning.description!,
                          style: TextStyle(color: _textColor(topWarning).withOpacity(0.8), fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _expanded ? '收起 ∧' : '展開 ${_warnings.length - 1} 個警告 ∨',
                      style: TextStyle(
                        color: _textColor(topWarning),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // 展开的其他警告
        if (_expanded && hasMore)
          ..._warnings.skip(1).map((w) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _backgroundColor(w),
                  border: Border(
                    top: BorderSide(color: _textColor(w).withOpacity(0.15), width: 0.5),
                  ),
                  borderRadius: w == _warnings.last
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(_warningIcon(w), color: _textColor(w), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _warningText(w),
                        style: TextStyle(
                          color: _textColor(w),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _WarningItem {
  final String code;
  final String name;
  final int level;       // 警告等级 (1/2/3)
  final int priority;    // 优先级 (1=最高)
  final String issueTime;
  final String updateTime;
  final String? expireTime;
  final String? description;
  final String? warningLevel; // HSWW: AMBER/RED/BLACK
  final String? type;         // HKO warnsum type 字段（暴雨: 黃色/紅色/黑色；台风: 八號東北/三號/十號）

  _WarningItem({
    required this.code,
    required this.name,
    required this.level,
    required this.priority,
    required this.issueTime,
    required this.updateTime,
    this.expireTime,
    this.description,
    this.warningLevel,
    this.type,
  });
}
