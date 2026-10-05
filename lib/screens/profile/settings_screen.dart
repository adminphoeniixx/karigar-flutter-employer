import 'package:flutter/material.dart' hide Text;
import '../../widgets/localized_text.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/app_language.dart';
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/auth/onboarding_screen.dart';
import 'package:employer_kariger_app/screens/profile/account_management_screen.dart';

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
          darkTheme = preferences['theme'] == 'dark';
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

  Future<void> _updatePreference(Map<String, dynamic> values) async {
    try {
      await AppScope.of(context).api.updatePreferences(values);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$exception')));
      }
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
                    onChanged: (value) {
                      setState(() => darkTheme = value);
                      _updatePreference({'theme': value ? 'dark' : 'light'});
                    },
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.bell,
                  title: context.tr('Applicant alerts'),
                  subtitle: context.tr('Get notified on new applications'),
                  trailing: _CompactSwitch(
                    value: applicantAlerts,
                    onChanged: (value) {
                      setState(() => applicantAlerts = value);
                      _updatePreference({'applicant_alerts': value});
                    },
                  ),
                ),
                _SettingsRow(
                  icon: LucideIcons.messageSquare,
                  title: context.tr('Message alerts'),
                  subtitle: context.tr('Get notified about worker messages'),
                  trailing: _CompactSwitch(
                    value: messageAlerts,
                    onChanged: (value) {
                      setState(() => messageAlerts = value);
                      _updatePreference({'message_alerts': value});
                    },
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
                ),
                _SettingsRow(
                  icon: LucideIcons.circleHelp,
                  title: context.tr('Help & Support'),
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
                      backgroundColor: AppColors.card,
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFFFE4E6)),
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
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5),
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
      backgroundColor: AppColors.card,
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
                    color: AppColors.line,
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
  Widget build(BuildContext context) => Container(
    height: 59,
    padding: const EdgeInsets.fromLTRB(20, 29, 20, 7),
    color: AppColors.background,
    alignment: Alignment.bottomLeft,
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
      ),
    ),
  );
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 69),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.line2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.brand50,
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
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              const Text(
                '→',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
        ],
      ),
    ),
  );
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
      activeTrackColor: AppColors.primary,
      activeThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFD1D5DB),
      inactiveThumbColor: Colors.white,
    ),
  );
}
