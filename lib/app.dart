import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';
import 'controllers/employer_controllers.dart';
import 'core/api/api_client.dart';
import 'core/app_scope.dart';
import 'core/theme.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/dashboard/main_shell.dart';
import 'services/employer_api_service.dart';

class KarigarEmployerApp extends StatefulWidget {
  const KarigarEmployerApp({super.key});

  @override
  State<KarigarEmployerApp> createState() => _KarigarEmployerAppState();
}

class _KarigarEmployerAppState extends State<KarigarEmployerApp> {
  late final ApiClient client;
  late final EmployerApiService api;
  late final AuthController auth;
  late final DashboardController dashboard;
  late final JobsController jobs;
  late final WorkersController workers;
  late final ProfileController profile;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    client = ApiClient();
    api = EmployerApiService(client);
    auth = AuthController(api);
    dashboard = DashboardController(api);
    jobs = JobsController(api);
    workers = WorkersController(api);
    profile = ProfileController(api);
    auth.restore().whenComplete(() {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    client.close();
    auth.dispose();
    dashboard.dispose();
    jobs.dispose();
    workers.dispose();
    profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    api: api,
    auth: auth,
    dashboard: dashboard,
    jobs: jobs,
    workers: workers,
    profile: profile,
    child: MaterialApp(
      title: 'Karigar Employer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: !ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.authenticated
          ? const MainShell()
          : const OnboardingScreen(),
    ),
  );
}
