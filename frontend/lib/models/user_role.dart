/// 用户角色枚举
enum UserRole {
  worker('worker', '工人'),
  contractor('contractor', '分判商'),
  siteManager('site_manager', '地盤經理'),
  projectManager('project_manager', '項目經理'),
  installManager('install_manager', '安裝經理'),
  safetyOfficer('safety_officer', '安全人員'),
  notifiedParty('notified_party', '知會人員'),
  superAdmin('super_admin', '超級管理員');

  final String value;
  final String label;
  const UserRole(this.value, this.label);

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.worker,
    );
  }

  /// 判断是否为内部管理角色（可访问 InternalHomePage）
  bool get isInternalStaff {
    return this == siteManager || this == projectManager ||
        this == installManager || this == superAdmin ||
        this == safetyOfficer;
  }
}
