/// 用户角色枚举
enum UserRole {
  worker('worker', '工人'),
  contractor('contractor', '分判商'),
  siteManager('site_manager', '地盤經理'),
  projectManager('project_manager', '項目經理'),
  superAdmin('super_admin', '超級管理員');

  final String value;
  final String label;
  const UserRole(this.value, this.label);

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.worker,
    );
  }
}
