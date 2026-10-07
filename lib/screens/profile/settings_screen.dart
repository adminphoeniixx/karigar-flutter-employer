import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/app_language.dart';
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';
import 'package:employer_kariger_app/screens/profile/account_management_screen.dart';
import 'package:employer_kariger_app/screens/profile/legal_support_screen.dart';

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
  // Do not let a slower preferences request undo a choice made on this page.
  bool _themeChangedLocally = false;

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
      if (!_themeChangedLocally) {
        await AppScope.of(context).appTheme.setServerValue(
          preferences is Map ? preferences['theme']?.toString() : null,
        );
      }
      if (!mounted) return;
      setState(() {
        if (preferences is Map) {
          if (!_themeChangedLocally) {
            darkTheme = AppScope.of(context).appTheme.isDark;
          }
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
    _themeChangedLocally = true;
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
              padding: EdgeInsets.zero,
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
                  subtitle: context.tr('Get notified about worker messages'),
                  trailing: _CompactSwitch(
                    value: messageAlerts,
                    onChanged: (value) =>
                        _changeAlert(value: value, isApplicantAlert: false),
                  ),
                ),
                _SectionHeader(context.tr('Account & Security')),
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
                      minimumSize: const Size.fromHeight(48),
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
        await api.setLocale(selected);
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 59,
      padding: const EdgeInsets.fromLTRB(20, 29, 20, 7),
      color: colors.surfaceContainerLow,
      alignment: Alignment.bottomLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 69),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
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
                Text(
                  '→',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
          ],
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
