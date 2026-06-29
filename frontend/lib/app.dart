import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fareast_worker_app/config/theme.dart';
import 'package:fareast_worker_app/config/routes.dart';
import 'package:fareast_worker_app/pages/splash_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '遠東工地通',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashPage(),
      onGenerateRoute: AppRouter.generateRoute,
      locale: const Locale('zh', 'HK'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'HK'),
        Locale('zh', 'CN'),
        Locale('en'),
      ],
    );
  }
}
