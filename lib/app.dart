import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'controllers/account_data_reset.dart';
import 'controllers/auth_controller.dart';
import 'screens/auth/registration_screen.dart';
import 'controllers/employer_controllers.dart';
import 'core/api/api_client.dart';
import 'core/app_scope.dart';
import 'core/app_language.dart';
import 'core/theme.dart';
import 'core/app_theme_controller.dart';
import 'core/push/push_notifications.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard/main_shell.dart';
import 'services/employer_api_service.dart';

class KarigarEmployerApp extends StatefulWidget {
  const KarigarEmployerApp({super.key, this.onInitialize});

  final Future<void> Function()? onInitialize;

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
  late final AppLanguage language;
  late final AppThemeController theme;
  late final AccountDataReset accountDataReset;
  late final PushNotifications push;
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _pushStarted = false;
  bool ready = false;
  String? maintenanceMessage;
  DateTime? maintenanceUntil;
  String? updateMessage;
  String? updateUrl;
  String? updateVersion;
  bool forceUpdate = false;

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
    language = AppLanguage();
    theme = AppThemeController();
    accountDataReset = AccountDataReset(auth, [
      dashboard.clear,
      jobs.clear,
      workers.clear,
      profile.clear,
    ]);
    push = PushNotifications(
      api: api,
      navigatorKey: navigatorKey,
      messengerKey: messengerKey,
    );
    auth.beforeLogout = push.stop;
    auth.addListener(_syncPush);
    Future.wait<void>([
      _initialize(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]).whenComplete(() {
      if (!mounted) return;
      setState(() => ready = true);
      final signedIn = _syncPush();
      // A push tapped while the app was closed: open its screen over home.
      if (signedIn) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => push.openLaunchMessage(),
        );
      }
    });
  }

  /// Push starts once the app has started (Firebase is up) and an employer is
  /// signed in, and is marked stopped again on sign-out. Returns whether an
  /// employer is signed in.
  bool _syncPush() {
    final role = auth.user?['role']?.toString().toLowerCase();
    final employer = auth.authenticated && (role == null || role == 'employer');
    if (!employer) {
      _pushStarted = false;
      return false;
    }
    if (ready && !_pushStarted) {
      _pushStarted = true;
      push.start();
    }
    return true;
  }

  Future<void> _initialize() async {
    // Paint the existing splash before starting platform initialization.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    // Everything the splash waits for runs side by side, so a slow network
    // costs one wait, not three in a row. Each step swallows its own failure:
    // a Firebase timeout or a failed check must never skip restoring the
    // saved login, which would show a signed-in user the login screen.
    final results = await Future.wait<Object?>([
      _quietly(widget.onInitialize?.call()),
      _quietly(api.maintenance()),
      _quietly(
        api.appUpdate(
          platform: Platform.isIOS ? 'ios' : 'android',
          version: '1.0.0',
        ),
      ),
      _quietly(auth.restore(), timeout: const Duration(seconds: 12)),
      _quietly(language.restore()),
      _quietly(theme.restore()),
    ]);
    if (!mounted) return;
    final maintenance = results[1];
    if (maintenance is Map && maintenance['maintenance'] == true) {
      maintenanceMessage =
          maintenance['message']?.toString() ??
          'We are improving Super Karigar. Back soon.';
      maintenanceUntil = DateTime.tryParse(
        '${maintenance['until'] ?? ''}',
      )?.toLocal();
      return;
    }
    final update = results[2];
    if (update is Map && update['update_available'] == true) {
      updateMessage =
          update['message']?.toString() ??
          'A newer version of Super Karigar is available.';
      updateUrl = update['store_url']?.toString();
      updateVersion = update['latest_version']?.toString();
      forceUpdate = update['force_update'] == true;
    }
  }

  /// The step's result, or null when it fails or takes longer than [timeout].
  Future<Object?> _quietly(
    Future<Object?>? step, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (step == null) return null;
    try {
      return await step.timeout(timeout);
    } catch (error) {
      debugPrint('[Startup] step skipped: $error');
      return null;
    }
  }

  @override
  void dispose() {
    accountDataReset.dispose();
    auth.removeListener(_syncPush);
    push.dispose();
    client.close();
    auth.dispose();
    dashboard.dispose();
    jobs.dispose();
    workers.dispose();
    profile.dispose();
    language.dispose();
    theme.dispose();
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
    language: language,
    theme: theme,
    child: AnimatedBuilder(
      animation: Listenable.merge([language, theme]),
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        title: 'Super Karigar Employer',
        debugShowCheckedModeBanner: false,
        locale: language.materialLocale,
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
          Locale('ta'),
          Locale('te'),
          Locale('bn'),
          Locale('mr'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme.mode,
        // The two Material themes contain framework-provided text styles with
        // different `inherit` values.  Animating between them makes Flutter
        // interpolate those incompatible styles and throws while an
        // OutlinedButton is on screen (for example, Settings > Log out).
        // Apply a user-selected theme immediately instead.
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          // Use the app's designed type scale so system accessibility scaling
          // cannot make individual labels or controls disproportionate.
          minScaleFactor: 1.0,
          maxScaleFactor: 1.0,
          child: child!,
        ),
        home: !ready
            ? const SplashScreen()
            : maintenanceMessage != null
            ? _MaintenanceScreen(
                message: maintenanceMessage!,
                until: maintenanceUntil,
                onRetry: () async {
                  setState(() => maintenanceMessage = null);
                  await _initialize();
                  if (mounted) setState(() {});
                },
              )
            : forceUpdate
            ? _UpdateScreen(message: updateMessage!, storeUrl: updateUrl)
            : auth.authenticated
            ? _OptionalUpdatePrompt(
                message: updateMessage,
                storeUrl: updateUrl,
                version: updateVersion,
                // A sign-up left half way (app closed before step 5) used to
                // open Home with an empty profile, and never asked again.
                child: employerNeedsRegistration(auth.user)
                    ? const RegistrationScreen()
                    : const MainShell(),
              )
            : _OptionalUpdatePrompt(
                message: updateMessage,
                storeUrl: updateUrl,
                version: updateVersion,
                child: const OnboardingScreen(),
              ),
      ),
    ),
  );
}

class _OptionalUpdatePrompt extends StatefulWidget {
  const _OptionalUpdatePrompt({
    required this.child,
    this.message,
    this.storeUrl,
    this.version,
  });
  final Widget child;
  final String? message, storeUrl, version;
  @override
  State<_OptionalUpdatePrompt> createState() => _OptionalUpdatePromptState();
}

class _OptionalUpdatePromptState extends State<_OptionalUpdatePrompt> {
  bool shown = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (shown || widget.message == null || widget.version == null) return;
    shown = true;
    _showIfNeeded();
  }

  Future<void> _showIfNeeded() async {
    final version = widget.version!;
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || preferences.getString('shown_update_version') == version) {
      return;
    }
    await preferences.setString('shown_update_version', version);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => _UpdateDialog(
          message: widget.message!,
          storeUrl: widget.storeUrl,
          onLater: () async {
            await preferences.setString('dismissed_update_version', version);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.message,
    this.storeUrl,
    required this.onLater,
  });
  final String message;
  final String? storeUrl;
  final Future<void> Function() onLater;
  Future<void> _open(BuildContext context) async {
    final url = Uri.tryParse(storeUrl ?? '');
    if (url == null || url.scheme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Update link is not available yet. Please try again later.',
          ),
        ),
      );
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the update link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New version available'),
    content: Text(message),
    actions: [
      TextButton(onPressed: onLater, child: const Text('Later')),
      if (storeUrl?.trim().isNotEmpty == true)
        FilledButton(
          onPressed: () => _open(context),
          child: const Text('Update'),
        ),
    ],
  );
}

class _UpdateScreen extends StatelessWidget {
  const _UpdateScreen({required this.message, this.storeUrl});
  final String message;
  final String? storeUrl;
  @override
  Widget build(BuildContext context) => _MaintenanceScreen(
    message: message,
    until: null,
    onRetry: () async {
      final url = Uri.tryParse(storeUrl ?? '');
      if (url != null && url.scheme.isNotEmpty) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    },
    title: 'Update required',
    buttonLabel: 'Update now',
  );
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({
    required this.message,
    required this.until,
    required this.onRetry,
    this.title = 'We’ll be back soon',
    this.buttonLabel = 'Check again',
  });
  final String message;
  final DateTime? until;
  final Future<void> Function() onRetry;
  final String title, buttonLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.construction_rounded,
                    color: colors.primary,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (until != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Expected back by ${MaterialLocalizations.of(context).formatMediumDate(until!)}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
