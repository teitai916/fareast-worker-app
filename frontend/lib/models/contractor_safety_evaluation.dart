/// 分判商安全考核评分数据模型
class ContractorSafetyEvaluation {
  final int? id;
  final int? siteId;
  final String? siteName;
  final int? companyId;
  final String? companyName;
  final String? tradeOfWork;
  final String? period;
  final int? periodYear;
  final int? periodQuarter;

  /// 21项评分 (key: 评分项名称, value: 评分 0-10)
  final Map<String, int?> scores;

  final int? totalScore;
  final double? percentage;
  final String? nonCompliantLevel;

  final String? status;
  final int? submittedBy;
  final String? submittedByName;
  final String? submittedAt;
  final int? assignedTo;
  final String? assignedToName;
  final int? approvedBy;
  final String? approvedByName;
  final String? approvedAt;
  final String? approvalComment;
  final String? notifiedAt;

  final String? evidenceAttachments;
  final String? remarks;

  final String? createdAt;
  final String? updatedAt;

  ContractorSafetyEvaluation({
    this.id,
    this.siteId,
    this.siteName,
    this.companyId,
    this.companyName,
    this.tradeOfWork,
    this.period,
    this.periodYear,
    this.periodQuarter,
    required this.scores,
    this.totalScore,
    this.percentage,
    this.nonCompliantLevel,
    this.status,
    this.submittedBy,
    this.submittedByName,
    this.submittedAt,
    this.assignedTo,
    this.assignedToName,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.approvalComment,
    this.notifiedAt,
    this.evidenceAttachments,
    this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  factory ContractorSafetyEvaluation.fromJson(Map<String, dynamic> json) {
    Map<String, int?> scores = {};
    if (json['scores'] != null) {
      (json['scores'] as Map<String, dynamic>).forEach((key, value) {
        scores[key] = value != null ? (value as num).toInt() : null;
      });
    }

    return ContractorSafetyEvaluation(
      id: json['id'] as int?,
      siteId: json['siteId'] as int?,
      siteName: json['siteName'] as String?,
      companyId: json['companyId'] as int?,
      companyName: json['companyName'] as String?,
      tradeOfWork: json['tradeOfWork'] as String?,
      period: json['period'] as String?,
      periodYear: json['periodYear'] as int?,
      periodQuarter: json['periodQuarter'] as int?,
      scores: scores,
      totalScore: json['totalScore'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      nonCompliantLevel: json['nonCompliantLevel'] as String?,
      status: json['status'] as String?,
      submittedBy: json['submittedBy'] as int?,
      submittedByName: json['submittedByName'] as String?,
      submittedAt: json['submittedAt'] as String?,
      assignedTo: json['assignedTo'] as int?,
      assignedToName: json['assignedToName'] as String?,
      approvedBy: json['approvedBy'] as int?,
      approvedByName: json['approvedByName'] as String?,
      approvedAt: json['approvedAt'] as String?,
      approvalComment: json['approvalComment'] as String?,
      notifiedAt: json['notifiedAt'] as String?,
      evidenceAttachments: json['evidenceAttachments'] as String?,
      remarks: json['remarks'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      'companyId': companyId,
      'tradeOfWork': tradeOfWork,
      'period': period,
      'periodYear': periodYear,
      'periodQuarter': periodQuarter,
      'score1': scores['管理层安全态度'],
      'score2': scores['具備足夠能力的安全人員'],
      'score3': scores['提供安全訓練、指示及監督'],
      'score4': scores['地盤安全設施之提供及維持'],
      'score5': scores['合作性'],
      'score6': scores['提供予屬下員工及使用個人保護裝置'],
      'score7': scores['安全意外率'],
      'score8': scores['安全表現'],
      'score9': scores['提供施工方案及風險評估'],
      'score10': scores['聘請安全督導員'],
      'score11': scores['起重機械/裝置證書'],
      'score12': scores['高空工作'],
      'score13': scores['個人防護裝備使用情況'],
      'score14': scores['施工/物料擺放位置整潔'],
      'score15': scores['依照施工方案進行工序'],
      'score16': scores['改善態度'],
      'score17': scores['參與早會及安全施工程序會議'],
      'score18': scores['提供合適的工具'],
      'score19': scores['合約安全守則'],
      'score20': scores['法例(包括工作守則)'],
      'score21': scores['工傷事故記錄'],
      'evidenceAttachments': evidenceAttachments,
      'remarks': remarks,
    };
  }

  /// 非合规等级中文
  String get nonCompliantLabel {
    switch (nonCompliantLevel) {
      case 'WARNING':
        return '書面警告';
      case 'SEVERE':
        return '約談處分';
      default:
        return '合格';
    }
  }

  /// 状态中文
  String get statusLabel {
    switch (status) {
      case 'DRAFT':
        return '草稿';
      case 'SUBMITTED':
        return '待審批';
      case 'APPROVED':
        return '已通過';
      case 'NOTIFIED':
        return '已通知';
      default:
        return status ?? '未知';
    }
  }

  bool get isDraft => status == 'DRAFT';
  bool get isSubmitted => status == 'SUBMITTED';
  bool get isApproved => status == 'APPROVED';
  bool get isNotified => status == 'NOTIFIED';
}
