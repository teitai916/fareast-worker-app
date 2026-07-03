import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

/// 全局 NavigatorKey，供快捷操作跳转
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// App 快捷操作服务（长按图标）
class ShortcutService {
  static const _quickActions = QuickActions();

  static const checkIn = 'check_in';
  static const changeSite = 'change_site';
  static const changeCompany = 'change_company';
  static const scan = 'scan';
  static const reviewApply = 'review_apply';

  /// 初始化监听（main.dart 中调用一次）
  static void init() {
    _quickActions.initialize(_handleShortcut);
    debugPrint('ShortcutService: initialized');
  }

  /// 根据角色设置快捷菜单（null 表示清除）
  static void setupForRole(String? role) {
    if (role == null) {
      _quickActions.clearShortcutItems();
      return;
    }
    try {
      if (role == 'WORKER') {
        _quickActions.setShortcutItems([
          const ShortcutItem(type: checkIn, localizedTitle: '打卡', icon: 'shortcut_check_in'),
          const ShortcutItem(type: changeSite, localizedTitle: '更換地盤', icon: 'shortcut_change_site'),
        ]);
      } else if (role == 'CONTRACTOR') {
        _quickActions.setShortcutItems([
          const ShortcutItem(type: reviewApply, localizedTitle: '審核入盤', icon: 'shortcut_review'),
          const ShortcutItem(type: changeSite, localizedTitle: '更換地盤', icon: 'shortcut_change_site'),
          const ShortcutItem(type: changeCompany, localizedTitle: '更換公司', icon: 'shortcut_change_company'),
        ]);
      } else {
        // SITE_MANAGER / PROJECT_MANAGER / SUPER_ADMIN
        _quickActions.setShortcutItems([
          const ShortcutItem(type: scan, localizedTitle: '掃一掃', icon: 'shortcut_scan'),
          const ShortcutItem(type: checkIn, localizedTitle: '打卡', icon: 'shortcut_check_in'),
        ]);
      }
    } catch (e) {
      debugPrint('ShortcutService.setupForRole error: $e');
    }
    debugPrint('ShortcutService: shortcuts set for role=$role');
  }

  static void _handleShortcut(String type) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    String? route;
    switch (type) {
      case checkIn:
        route = '/worker/attendance';
        break;
      case changeSite:
        route = '/worker/change-site';
        break;
      case changeCompany:
        route = '/worker/change-company';
        break;
      case scan:
        route = '/internal/scan-deduct';
        break;
      case reviewApply:
        route = '/contractor/review';
        break;
    }
    if (route != null) nav.pushNamed(route);
  }
}
