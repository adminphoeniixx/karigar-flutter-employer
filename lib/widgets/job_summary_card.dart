import 'package:flutter/material.dart' hide Text;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'localized_text.dart';

/// The job card on Home ("Your active jobs") and My Jobs: a status-coloured
/// stripe on the left, the wage as a bold pill, and the applicant /
/// shortlisted / hired counts in their own colours, so the numbers that need
/// attention stand out.
class JobSummaryCard extends StatelessWidget {
  const JobSummaryCard({
    super.key,
    required this.job,
    required this.onTap,
    this.showModeration = false,
  });

  final Job job;
  final VoidCallback onTap;

  /// My Jobs also shows the safety-check state and note.
  final bool showModeration;

  static Color statusColor(String status) => switch (status.toLowerCase()) {
    'active' => AppColors.green,
    'draft' => AppColors.indigo,
    'under review' => AppColors.amber,
    'not approved' => AppColors.rose,
    _ => AppColors.muted,
  };

  static Color _statusBackground(String status) =>
      switch (status.toLowerCase()) {
        'active' => AppColors.greenBg,
        'draft' => AppColors.indigoBg,
        'under review' => AppColors.amberBg,
        'not approved' => AppColors.roseBg,
        _ => AppColors.line2,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checking = showModeration && job.moderationStatus == 'checking';
    final stripe = checking ? AppColors.indigo : statusColor(job.status);
    final accent = context.accentText(stripe);
    final pillBackground = context.accentBackground(
      stripe,
      checking ? AppColors.indigoBg : _statusBackground(job.status),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: stripe),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              job.category.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pillBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (checking)
                                  SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(width: 5),
                                Text(
                                  checking ? 'Checking…' : job.status,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 10, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              job.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: context.brandTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.arrowRight,
                              size: 15,
                              color: context.accentText(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Pill(
                            icon: LucideIcons.indianRupee,
                            label: context.trWage(job.wage),
                            color: AppColors.primary,
                            strong: true,
                          ),
                          _Pill(
                            icon: LucideIcons.usersRound,
                            label: context.trOpenings(job.openings),
                            color: AppColors.muted,
                          ),
                          if (job.views > 0)
                            _Pill(
                              icon: LucideIcons.eye,
                              label: '${job.views} views',
                              color: AppColors.muted,
                            ),
                        ],
                      ),
                    ),
                    if (showModeration &&
                        job.moderationNote?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 9),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          job.moderationNote!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.accentText(AppColors.rose),
                          ),
                        ),
                      ),
                    ],
                    if (showModeration &&
                        job.moderationStatus == 'approved') ...[
                      const SizedBox(height: 9),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.shieldCheck,
                              size: 13,
                              color: context.accentText(AppColors.green),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job.moderationMethod == 'phrases'
                                  ? 'Basic check'
                                  : 'AI checked',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.accentText(AppColors.green),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: context.softSurface,
                        border: Border(
                          top: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          _Metric(
                            icon: LucideIcons.inbox,
                            value: job.applied,
                            label: 'Applicants',
                            color: AppColors.primary,
                          ),
                          _Metric(
                            icon: LucideIcons.star,
                            value: job.shortlisted,
                            label: 'Shortlisted',
                            color: AppColors.amber,
                          ),
                          _Metric(
                            icon: LucideIcons.circleCheck,
                            value: job.hired,
                            label: 'Hired',
                            color: AppColors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.strong = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = strong
        ? context.accentText(color)
        : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? context.brandTint : Colors.transparent,
        border: Border.all(
          color: strong ? context.brandTintBorder : colors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: strong ? 13 : 12,
                color: foreground,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One count in the strip at the bottom: a tinted tile when it is above
/// zero, a quiet one at zero.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final live = value > 0;
    final accent = live ? context.accentText(color) : colors.onSurfaceVariant;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: live
                ? context.accentBackground(color, color.withValues(alpha: .08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: live ? accent : colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
