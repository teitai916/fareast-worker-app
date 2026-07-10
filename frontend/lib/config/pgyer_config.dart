/// 蒲公英（Pgyer）版本检测配置
/// 
/// 在蒲公英后台「API 信息」页面获取 _api_key 和 appKey：
/// https://www.pgyer.com/account/api
class PgyerConfig {
  /// 蒲公英 API Key（在蒲公英后台「API 信息」页面获取）
  /// 建议通过 --dart-define=PGYER_API_KEY=xxx 传入
  static const String apiKey = String.fromEnvironment(
    'PGYER_API_KEY',
  );

  /// 蒲公英 App Key（应用详情页可见）
  /// 建议通过 --dart-define=PGYER_APP_KEY=xxx 传入
  static const String appKey = String.fromEnvironment(
    'PGYER_APP_KEY',
  );

  /// 蒲公英版本检测 API
  static const String checkUpdateUrl = 'https://www.pgyer.com/apiv2/app/check';

  /// 是否已配置
  static bool get isConfigured => apiKey.isNotEmpty && appKey.isNotEmpty;
}
