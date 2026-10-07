import 'package:flutter/widgets.dart';

import '../controllers/auth_controller.dart';
import '../controllers/employer_controllers.dart';
import '../services/employer_api_service.dart';
import 'app_language.dart';
import 'app_theme_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.dashboard,
    required this.jobs,
    required this.workers,
    required this.profile,
    this.language,
    this.theme,
    required super.child,
  });

  final EmployerApiService api;
  final AuthController auth;
  final DashboardController dashboard;
  final JobsController jobs;
  final WorkersController workers;
  final ProfileController profile;
  final AppLanguage? language;
  final AppThemeController? theme;
  static final AppThemeController _fallbackTheme = AppThemeController();
  AppThemeController get appTheme => theme ?? _fallbackTheme;
  AppLanguage get appLanguage => language ?? AppLanguage.shared;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
