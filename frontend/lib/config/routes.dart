import 'package:flutter/material.dart';
import 'package:fareast_worker_app/models/contractor_safety_evaluation.dart';
import 'package:fareast_worker_app/pages/auth/login_page.dart';
import 'package:fareast_worker_app/pages/auth/login_form_page.dart';
import 'package:fareast_worker_app/pages/auth/register_page.dart';
import 'package:fareast_worker_app/pages/auth/forgot_password_page.dart';
import 'package:fareast_worker_app/pages/worker/worker_home_page.dart';
import 'package:fareast_worker_app/pages/worker/worker_register_page.dart';
import 'package:fareast_worker_app/pages/worker/safety_videos_page.dart';
import 'package:fareast_worker_app/pages/worker/attendance_page.dart';
import 'package:fareast_worker_app/pages/worker/change_site_page.dart';
import 'package:fareast_worker_app/pages/worker/site_detail_page.dart';
import 'package:fareast_worker_app/pages/worker/history_sites_page.dart';
import 'package:fareast_worker_app/pages/worker/site_apply_page.dart';
import 'package:fareast_worker_app/pages/worker/change_company_page.dart';
import 'package:fareast_worker_app/pages/contractor/contractor_home_page.dart';
import 'package:fareast_worker_app/pages/contractor/contractor_review_page.dart';
import 'package:fareast_worker_app/pages/notifications_page.dart';
import 'package:fareast_worker_app/pages/admin/admin_home_page.dart';
import 'package:fareast_worker_app/pages/internal/internal_home_page.dart';
import 'package:fareast_worker_app/pages/internal/scan_deduct_page.dart';
import 'package:fareast_worker_app/pages/safety/evaluation_list_page.dart';
import 'package:fareast_worker_app/pages/safety/evaluation_form_page.dart';
import 'package:fareast_worker_app/pages/safety/evaluation_detail_page.dart';
import 'package:fareast_worker_app/pages/safety/non_compliant_list_page.dart';

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
      case '/worker/safety-videos':
        return MaterialPageRoute(builder: (_) => const SafetyVideosPage());
      case '/worker/attendance':
        return MaterialPageRoute(builder: (_) => const AttendancePage());
      case '/worker/change-site':
        return MaterialPageRoute(builder: (_) => const ChangeSitePage());
      case '/worker/change-company':
        return MaterialPageRoute(builder: (_) => const ChangeCompanyPage());
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
      case '/internal/home':
        return MaterialPageRoute(builder: (_) => const InternalHomePage());
      case '/internal/scan-deduct':
        return MaterialPageRoute(builder: (_) => const ScanDeductPage());
      case '/safety/evaluations':
        return MaterialPageRoute(builder: (_) => const EvaluationListPage());
      case '/safety/evaluation-form':
        final args = settings.arguments;
        if (args is Map) {
          return MaterialPageRoute(builder: (_) => EvaluationFormPage(
            evaluationId: args['id'] as int?,
            existing: args['existing'] as ContractorSafetyEvaluation?,
          ));
        }
        return MaterialPageRoute(builder: (_) => const EvaluationFormPage());
      case '/safety/evaluation-detail':
        final evalId = settings.arguments as int? ?? 0;
        return MaterialPageRoute(builder: (_) => EvaluationDetailPage(evaluationId: evalId));
      case '/safety/non-compliant':
        return MaterialPageRoute(builder: (_) => const NonCompliantListPage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
