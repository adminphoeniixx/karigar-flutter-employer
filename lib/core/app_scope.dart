import 'package:flutter/widgets.dart';

import '../controllers/auth_controller.dart';
import '../controllers/employer_controllers.dart';
import '../services/employer_api_service.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.dashboard,
    required this.jobs,
    required this.workers,
    required this.profile,
    required super.child,
  });

  final EmployerApiService api;
  final AuthController auth;
  final DashboardController dashboard;
  final JobsController jobs;
  final WorkersController workers;
  final ProfileController profile;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
