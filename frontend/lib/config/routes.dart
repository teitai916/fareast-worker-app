import 'package:flutter/material.dart';
import 'package:fareast_worker_app/pages/auth/login_page.dart';
import 'package:fareast_worker_app/pages/auth/login_form_page.dart';
import 'package:fareast_worker_app/pages/auth/register_page.dart';
import 'package:fareast_worker_app/pages/auth/forgot_password_page.dart';
import 'package:fareast_worker_app/pages/worker/worker_home_page.dart';
import 'package:fareast_worker_app/pages/worker/worker_register_page.dart';
import 'package:fareast_worker_app/pages/worker/face_register_page.dart';
import 'package:fareast_worker_app/pages/worker/safety_videos_page.dart';
import 'package:fareast_worker_app/pages/worker/attendance_page.dart';
import 'package:fareast_worker_app/pages/worker/change_site_page.dart';
import 'package:fareast_worker_app/pages/worker/site_detail_page.dart';
import 'package:fareast_worker_app/pages/worker/history_sites_page.dart';
import 'package:fareast_worker_app/pages/worker/site_apply_page.dart';
import 'package:fareast_worker_app/pages/contractor/contractor_home_page.dart';
import 'package:fareast_worker_app/pages/contractor/contractor_review_page.dart';
import 'package:fareast_worker_app/pages/notifications_page.dart';
import 'package:fareast_worker_app/pages/admin/admin_home_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/login-form':
        return MaterialPageRoute(builder: (_) => const LoginFormPage());
      case '/register':
        final role = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => RegisterPage(initialRole: role));
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());
      case '/worker/home':
        return MaterialPageRoute(builder: (_) => const WorkerHomePage());
      case '/worker/register':
        return MaterialPageRoute(builder: (_) => const WorkerRegisterPage());
      case '/worker/register-face':
        return MaterialPageRoute(builder: (_) => const FaceRegisterPage());
      case '/worker/safety-videos':
        return MaterialPageRoute(builder: (_) => const SafetyVideosPage());
      case '/worker/attendance':
        return MaterialPageRoute(builder: (_) => const AttendancePage());
      case '/worker/change-site':
        return MaterialPageRoute(builder: (_) => const ChangeSitePage());
      case '/worker/site-detail':
        return MaterialPageRoute(builder: (_) => const SiteDetailPage());
      case '/worker/history-sites':
        return MaterialPageRoute(builder: (_) => const HistorySitesPage());
      case '/worker/apply-site':
        return MaterialPageRoute(builder: (_) => SiteApplyPage());
      case '/contractor/home':
        return MaterialPageRoute(builder: (_) => const ContractorHomePage());
      case '/contractor/review':
        return MaterialPageRoute(builder: (_) => const ContractorReviewPage());
      case '/notifications':
        return MaterialPageRoute(builder: (_) => const NotificationsPage());
      case '/admin/home':
        return MaterialPageRoute(builder: (_) => const AdminHomePage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
