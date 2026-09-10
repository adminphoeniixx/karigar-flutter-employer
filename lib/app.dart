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
    Future.wait<void>([
      auth.restore(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]).whenComplete(() {
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
      title: 'Super Karigar Employer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child!,
      ),
      home: !ready
          ? const _AppSplash()
          : auth.authenticated
          ? const MainShell()
          : const OnboardingScreen(),
    ),
  );
}

class _AppSplash extends StatelessWidget {
  const _AppSplash();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brand400,
            AppColors.primary,
            AppColors.gradientEnd,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipOval(
                child: Container(
                  width: 180,
                  height: 180,
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/icon/super_karigar_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Super Karigar Employer',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Kaam. Hunar. Bharosa.',
              style: TextStyle(
                color: AppColors.brand100,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: .4,
              ),
            ),
            const Spacer(flex: 3),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    ),
  );
}
