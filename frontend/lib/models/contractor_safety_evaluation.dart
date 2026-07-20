/// 分判商安全考核评分数据模型
import 'package:fareast_worker_app/config/safety_score_config.dart';

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
      ...{for (final i in SafetyScoreConfig.names.keys) 'score$i': scores[SafetyScoreConfig.name(i)]},
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
