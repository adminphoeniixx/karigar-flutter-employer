import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/app_language.dart';
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';
import 'package:employer_kariger_app/screens/profile/account_management_screen.dart';
import 'package:employer_kariger_app/screens/profile/legal_support_screen.dart';
import 'package:employer_kariger_app/screens/profile/ai_call_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkTheme = false;
  bool applicantAlerts = true;
  bool messageAlerts = true;
  List<String> languageCodes = const ['en', 'hi', 'ta', 'te', 'bn', 'mr'];
  bool loaded = false;
  bool loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      // The app theme may already have been restored from local storage before
      // the settings API request finishes.  Keep the switch in sync from its
      // first frame instead of briefly showing the opposite value.
      darkTheme = AppScope.of(context).appTheme.isDark;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final api = AppScope.of(context).api;
      final results = await Future.wait([api.preferences(), api.reference()]);
      final response = results.first;
      final preferences = response['preferences'];
      final reference = results.last;
      if (!mounted) return;
      setState(() {
        if (preferences is Map) {
          // Theme is controlled by the local, explicit toggle.  Never let a
          // stale server preference switch the whole app merely by opening
          // Settings.
          darkTheme = AppScope.of(context).appTheme.isDark;
          applicantAlerts = preferences['applicant_alerts'] != false;
          messageAlerts = preferences['message_alerts'] != false;
        }
        final serverCodes = (reference['app_languages'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => '${item['code']}')
            .where((code) => code.isNotEmpty)
            .toList();
        if (serverCodes.isNotEmpty) languageCodes = serverCodes;
      });
    } catch (_) {
      // Keep the current defaults if preferences cannot be fetched.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> _updatePreference(Map<String, dynamic> values) async {
    try {
      await AppScope.of(context).api.updatePreferences(values);
      return true;
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
      return false;
    }
  }

  Future<void> _changeDarkTheme(bool value) async {
    final oldValue = darkTheme;
    final theme = AppScope.of(context).appTheme;
    setState(() => darkTheme = value);
    try {
      await theme.setDark(value);
    } catch (exception) {
      if (!mounted) return;
      setState(() => darkTheme = oldValue);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$exception')));
      return;
    }
    if (!await _updatePreference({'theme': value ? 'dark' : 'light'})) {
      await theme.setDark(oldValue);
      if (mounted) setState(() => darkTheme = oldValue);
    }
  }

  Future<void> _changeAlert({
    required bool value,
    required bool isApplicantAlert,
  }) async {
    final oldValue = isApplicantAlert ? applicantAlerts : messageAlerts;
    setState(() {
      if (isApplicantAlert) {
        applicantAlerts = value;
      } else {
        messageAlerts = value;
      }
    });
    final key = isApplicantAlert ? 'applicant_alerts' : 'message_alerts';
    if (!await _updatePreference({key: value}) && mounted) {
      setState(() {
        if (isApplicantAlert) {
          applicantAlerts = oldValue;
        } else {
          messageAlerts = oldValue;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 58,
      title: Text(
        context.tr('Settings'),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    body: AnimatedBuilder(
      animation: AppScope.of(context).appLanguage,
      builder: (context, _) => loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SectionHeader(context.tr('Preferences')),
                _SettingsRow(
                  icon: LucideIcons.globe2,
                  title: context.tr('Language'),
                  subtitle: AppLanguage.label(
                    AppScope.of(context).appLanguage.locale.languageCode,
                  ),
                  onTap: _showLanguageSheet,
                ),
                _SettingsRow(
                  icon: LucideIcons.moon,
                  title: context.tr('Dark theme'),
                  subtitle: context.tr('Switch to a darker screen'),
                  trailing: _CompactSwitch(
                    value: darkTheme,
                    onChanged: _changeDarkTheme,
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.bell,
                  title: context.tr('Applicant alerts'),
                  subtitle: context.tr('Get notified on new applications'),
                  trailing: _CompactSwitch(
                    value: applicantAlerts,
                    onChanged: (value) =>
                        _changeAlert(value: value, isApplicantAlert: true),
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.messageSquare,
                  title: context.tr('Message alerts'),
                  subtitle: context.tr('Get notified about karigar messages'),
                  trailing: _CompactSwitch(
                    value: messageAlerts,
                    onChanged: (value) =>
                        _changeAlert(value: value, isApplicantAlert: false),
                  ),
                ),
                _SectionHeader(context.tr('Account & Security')),
                _SettingsRow(
                  icon: LucideIcons.phoneCall,
                  title: 'AI call settings',
                  subtitle: 'Choose when applicants receive AI calls',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AiCallSettingsScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.lockKeyhole,
                  title: context.tr('Login & security'),
                  subtitle: context.tr('OTP · device sessions'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeviceSessionsScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.usersRound,
                  title: context.tr('Team members'),
                  subtitle: context.tr('Add recruiters to your account'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeamMembersScreen(),
                    ),
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.fileText,
                  title: context.tr('Terms & Privacy'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalScreen()),
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.circleHelp,
                  title: context.tr('Help & Support'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.trash2,
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account and data',
                  danger: true,
                  onTap: _showDeleteAccountSheet,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AppScope.of(context).auth.logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.errorContainer,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(LucideIcons.logOut, size: 19),
                    label: Text(context.tr('Log out')),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('Super Karigar Employer · v1.0.0'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
    ),
  );

  Future<void> _showLanguageSheet() async {
    final api = AppScope.of(context).api;
    final appLanguage = AppScope.of(context).appLanguage;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                context.tr('Choose language'),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...languageCodes.map(
                (code) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLanguage.label(code)),
                  trailing: code == appLanguage.locale.languageCode
                      ? const Icon(LucideIcons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      try {
        // The API's Hindi locale also carries the Hindi + English preference;
        // the app keeps the distinct local Hinglish presentation.
        await api.setLocale(selected == 'hinglish' ? 'hi' : selected);
        await appLanguage.select(selected);
      } catch (exception) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$exception')));
        }
      }
    }
  }

  Future<void> _showDeleteAccountSheet() async {
    final api = AppScope.of(context).api;
    Map<String, dynamic>? details;
    String? loadError;
    var acknowledged = false;
    var deleting = false;
    var loadingDetails = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> load() async {
            if (loadingDetails) return;
            loadingDetails = true;
            try {
              final response = await api.accountDeletion();
              if (!sheetContext.mounted) return;
              setSheetState(() => details = response);
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() => loadError = readableMessage('$error'));
            } finally {
              loadingDetails = false;
            }
          }

          if (details == null && loadError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => load());
          }

          final canDelete = details?['can_delete'] == true;
          final warnings = (details?['warnings'] as List? ?? const [])
              .whereType<Object>()
              .map((warning) => '$warning')
              .toList();
          final blockedMessage = readableMessage(
            details?['blocked_message']?.toString(),
            fallback: 'This account cannot be deleted.',
          );
          final colors = Theme.of(sheetContext).colorScheme;

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Delete your account?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (details == null && loadError == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (loadError != null)
                        _DeleteNotice(message: loadError!, isError: true)
                      else ...[
                        if (!canDelete)
                          _DeleteNotice(message: blockedMessage, isError: true)
                        else ...[
                          ...warnings.map(
                            (warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(
                                      LucideIcons.alertTriangle,
                                      size: 16,
                                      color: colors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      warning,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            value: acknowledged,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'I understand this cannot be undone',
                              style: TextStyle(fontSize: 13.5),
                            ),
                            onChanged: deleting
                                ? null
                                : (value) => setSheetState(
                                    () => acknowledged = value ?? false,
                                  ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: deleting
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          if (canDelete) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.error,
                                  foregroundColor: colors.onError,
                                ),
                                onPressed: acknowledged && !deleting
                                    ? () async {
                                        setSheetState(() => deleting = true);
                                        try {
                                          final response = await api
                                              .deleteAccount();
                                          if (!sheetContext.mounted) return;
                                          await _completeAccountDeletion(
                                            response['message']?.toString(),
                                          );
                                        } on ApiException catch (error) {
                                          if (sheetContext.mounted) {
                                            setSheetState(
                                              () => deleting = false,
                                            );
                                            ScaffoldMessenger.of(
                                              sheetContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error.message),
                                              ),
                                            );
                                          }
                                        } catch (_) {
                                          if (sheetContext.mounted) {
                                            setSheetState(
                                              () => deleting = false,
                                            );
                                            ScaffoldMessenger.of(
                                              sheetContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Could not delete the account. Please try again.',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                child: deleting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Delete account'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _completeAccountDeletion(String? message) async {
    final scope = AppScope.of(context);
    await scope.api.client.setToken(null);
    scope.auth.clearSession();
    scope.dashboard.clear();
    scope.jobs.clear();
    scope.workers.clear();
    scope.profile.clear();
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          readableMessage(message, fallback: 'Your account has been deleted.'),
        ),
      ),
    );
  }
}

class _DeleteNotice extends StatelessWidget {
  const _DeleteNotice({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: isError ? colors.onErrorContainer : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = danger ? colors.error : colors.onPrimaryContainer;
    final iconBackground = danger
        ? colors.errorContainer
        : colors.primaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: danger ? colors.error : null,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: .83,
    child: Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: Theme.of(context).colorScheme.primary,
      activeThumbColor: Theme.of(context).colorScheme.onPrimary,
      inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      inactiveThumbColor: Theme.of(context).colorScheme.outline,
    ),
  );
}
