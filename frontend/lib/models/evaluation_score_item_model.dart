/// 評分項數據模型
class EvaluationScoreItemModel {
  final int scoreIndex;
  final String category;
  final String nameZh;
  final int sortOrder;
  final List<Map<String, String>> guides; // [{desc, range}]

  const EvaluationScoreItemModel({
    required this.scoreIndex,
    required this.category,
    required this.nameZh,
    required this.sortOrder,
    this.guides = const [],
  });

  factory EvaluationScoreItemModel.fromJson(Map<String, dynamic> json) {
    return EvaluationScoreItemModel(
      scoreIndex: (json['scoreIndex'] as num).toInt(),
      category: json['category'] as String? ?? '',
      nameZh: json['nameZh'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      guides: (json['guides'] as List<dynamic>?)
              ?.map((g) => {
                    'desc': (g['desc'] ?? '') as String,
                    'range': (g['range'] ?? '') as String,
                  })
              .toList() ??
          [],
    );
  }
}
