import 'package:flutter/material.dart' hide Text;

import '../core/app_strings.dart';
import 'localized_text.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/data.dart';
import '../core/theme.dart';

class BrandChip extends StatelessWidget {
  const BrandChip(this.text, {super.key, this.neutral = false});
  final String text;
  final bool neutral;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: neutral
            ? colors.surfaceContainerHighest
            : isDark
            ? colors.primary.withValues(alpha: .18)
            : AppColors.brand50,
        border: Border.all(
          color: neutral
              ? colors.outlineVariant
              : colors.primary.withValues(alpha: .35),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: neutral ? colors.onSurfaceVariant : colors.primary,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
    // Translated before upper-casing ("PERFORMANCE" is not in the Hindi
    // list, "Performance" is).
    child: Text(
      context.tr(text).toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A status badge. The API sends some statuses lower-case ("active") and the
/// app spells others out ("Active"): both read and look the same here.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key});
  final String text;

  /// "active" → "Active"; labels already written out are kept.
  static String label(String status) {
    final value = status.trim();
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final key = text.trim().toLowerCase();
    // Green for done/live, the same green as "Hired" on Home; the theme's
    // tertiary colour is a pending-looking yellow.
    final positive = ['active', 'hired', 'accepted', 'verified'].contains(key);
    final shortlisted = key == 'shortlisted';
    final rejected = ['rejected', 'closed', 'not approved'].contains(key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive
            ? context.accentBackground(AppColors.green, AppColors.greenBg)
            : shortlisted
            ? colors.secondaryContainer
            : rejected
            ? colors.errorContainer
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label(text),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: positive
              ? context.accentText(AppColors.green)
              : shortlisted
              ? colors.onSecondaryContainer
              : rejected
              ? colors.onErrorContainer
              : colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class WorkerCard extends StatelessWidget {
  const WorkerCard({
    super.key,
    required this.worker,
    this.onTap,
    this.maxSkills = 4,
    this.flat = false,
  });
  final Worker worker;
  final VoidCallback? onTap;
  final int maxSkills;

  /// No card of its own: the caller puts it inside a larger card.
  final bool flat;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Widget Function({required Widget child}) shell = flat
        ? ({required Widget child}) =>
              Material(type: MaterialType.transparency, child: child)
        : ({required Widget child}) => Card(child: child);
    return shell(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 310;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          worker.initials,
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    worker.name,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                if (worker.verified)
                                  const Icon(
                                    LucideIcons.badgeCheck,
                                    size: 17,
                                    color: AppColors.green,
                                  ),
                              ],
                            ),
                            Text(
                              [
                                worker.trade,
                                '${worker.experience} yrs exp',
                                if (worker.rating > 0) '★ ${worker.rating}',
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            if (worker.distance > 0 || worker.wage > 0) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  if (worker.distance > 0) ...[
                                    const Icon(
                                      LucideIcons.mapPin,
                                      size: 13,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${formatKm(worker.distance)} away',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                  if (worker.distance > 0 && worker.wage > 0)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  if (worker.wage > 0)
                                    Flexible(
                                      child: Text(
                                        monthlyWage(worker.wage),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!compact) StatusPill(worker.status),
                    ],
                  ),
                  if (compact) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(worker.status),
                    ),
                  ],
                  if (worker.skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.sparkles,
                          size: 13,
                          color: AppColors.muted,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Skills',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...worker.skills
                            .take(maxSkills)
                            .map((s) => BrandChip(s, neutral: true)),
                        if (worker.skills.length > maxSkills)
                          BrandChip(
                            '+${worker.skills.length - maxSkills} more',
                            neutral: true,
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField(
    this.label, {
    super.key,
    this.hint,
    this.lines = 1,
    this.keyboardType,
    this.controller,
    this.maxLength,
    this.errorText,
    this.focusNode,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });
  final String label;
  final String? hint;
  final int lines;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final int? maxLength;
  final String? errorText;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: lines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            counterText: maxLength == null ? null : '',
            errorText: errorText,
          ),
        ),
      ],
    ),
  );
}

/// A short, always-visible time for list rows: "2 weeks ago" becomes "2w".
/// The full label did not fit the time column and was cut to "2 weeks a…".
String shortAgo(String label) {
  final text = label.trim();
  if (text.isEmpty) return text;
  if (text.toLowerCase() == 'just now') return 'now';
  final match = RegExp(
    r'^(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return text;
  const units = {
    'second': 's',
    'minute': 'm',
    'hour': 'h',
    'day': 'd',
    'week': 'w',
    'month': 'mo',
    'year': 'y',
  };
  return '${match.group(1)}${units[match.group(2)!.toLowerCase()]}';
}

/// The last row of a paged list: a small spinner that asks for the next page
/// as soon as it is built, i.e. when the list has been scrolled to its end.
class PageEndLoader extends StatefulWidget {
  const PageEndLoader({super.key, required this.onReached});
  final VoidCallback onReached;
  @override
  State<PageEndLoader> createState() => _PageEndLoaderState();
}

class _PageEndLoaderState extends State<PageEndLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReached();
    });
  }

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

/// One way to show a distance everywhere: "2.3 km" up close, "1,453 km" far.
/// Screens used to mix "1453.1 km", "544.7 km" and "~545 km".
String formatKm(double km) {
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  final whole = km.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$whole km';
}

/// "Manager", "Recruiter": team roles arrive in lower case.
String roleLabel(String role) =>
    role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';
