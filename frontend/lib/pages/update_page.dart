import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/services/update_service.dart';

/// 更新提示页面
/// - forceUpdate=true：全屏不可关闭，用户必须点击更新
/// - forceUpdate=false：弹窗提示，用户可选择稍后更新
class UpdateHelper {
  /// 显示更新提示（根据是否需要强制更新决定展示形式）
  static Future<void> show(BuildContext context, UpdateResult result) {
    if (result.needForceUpdate) {
      return Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _ForceUpdatePage(result: result),
        ),
      );
    } else {
      return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _OptionalUpdateDialog(result: result),
      );
    }
  }
}

/// 强制更新页面（全屏，不可关闭）
class _ForceUpdatePage extends StatelessWidget {
  final UpdateResult result;

  const _ForceUpdatePage({required this.result});

  static const Color _blue = Color(0xFF2563EB);

  Future<void> _openDownload(BuildContext context) async {
    final url = result.downloadURL;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 顶部图标
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 44,
                    color: _blue,
                  ),
                ),
                const SizedBox(height: 28),

                // 标题
                const Text(
                  '發現新版本',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),

                // 版本号
                Text(
                  'v${result.latestVersion}',
                  style: TextStyle(
                    fontSize: 18,
                    color: _blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // 更新说明
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '更新內容',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.updateDescription?.isNotEmpty == true
                            ? result.updateDescription!
                            : '為了更好的使用體驗，請更新到最新版本',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF334155),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // 更新按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _openDownload(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '立即更新',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 底部提示
                const Text(
                  '更新完成後請重新打開 App',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 可选更新弹窗
class _OptionalUpdateDialog extends StatelessWidget {
  final UpdateResult result;

  const _OptionalUpdateDialog({required this.result});

  static const Color _blue = Color(0xFF2563EB);

  Future<void> _openDownload() async {
    final url = result.downloadURL;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.system_update_rounded, size: 32, color: _blue),
            ),
            const SizedBox(height: 16),
            const Text(
              '發現新版本',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'v${result.latestVersion}',
              style: const TextStyle(fontSize: 16, color: _blue, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (result.updateDescription?.isNotEmpty == true)
              Text(
                result.updateDescription!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('稍後更新', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('立即更新', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
