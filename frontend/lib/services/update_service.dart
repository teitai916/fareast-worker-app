import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fareast_worker_app/config/pgyer_config.dart';

/// 版本检测结果
class UpdateResult {
  final bool hasNewVersion;
  final bool needForceUpdate;
  final String latestVersion;
  final String? updateDescription;
  final String? downloadURL;

  UpdateResult({
    required this.hasNewVersion,
    required this.needForceUpdate,
    required this.latestVersion,
    this.updateDescription,
    this.downloadURL,
  });

  factory UpdateResult.fromJson(Map<String, dynamic> json) {
    return UpdateResult(
      hasNewVersion: json['buildHaveNewVersion'] == true,
      needForceUpdate: json['needForceUpdate'] == true,
      latestVersion: json['buildVersion'] ?? '',
      updateDescription: json['buildUpdateDescription'],
      downloadURL: json['downloadURL'] ?? json['appURl'],
    );
  }
}

/// 蒲公英版本检测服务
class UpdateService {
  /// 检查是否有新版本
  /// 返回 [UpdateResult]，失败返回 null
  static Future<UpdateResult?> checkUpdate() async {
    if (!PgyerConfig.isConfigured) return null;

    try {
      // 获取当前 App 版本号
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 调用蒲公英 API
      final response = await http.post(
        Uri.parse(PgyerConfig.checkUpdateUrl),
        body: {
          '_api_key': PgyerConfig.apiKey,
          'appKey': PgyerConfig.appKey,
          'buildVersion': currentVersion,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body['code'] != 0) return null;

      final data = body['data'];
      if (data == null) return null;

      return UpdateResult.fromJson(data);
    } catch (_) {
      // 网络异常或其他错误，静默失败（不影响正常使用）
      return null;
    }
  }
}
