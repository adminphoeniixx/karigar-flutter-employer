import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/data.dart';
import '../core/theme.dart';

class BrandChip extends StatelessWidget {
  const BrandChip(this.text, {super.key, this.neutral = false});
  final String text;
  final bool neutral;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: neutral ? Colors.white : AppColors.brand50,
      border: Border.all(color: neutral ? AppColors.line : AppColors.brand100),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: neutral ? AppColors.muted : AppColors.brandDark,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
        color: AppColors.muted,
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final positive = ['Active', 'Hired', 'Accepted', 'Verified'].contains(text);
    final shortlisted = text == 'Shortlisted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive
            ? AppColors.greenBg
            : shortlisted
            ? AppColors.indigoBg
            : AppColors.amberBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: positive
              ? AppColors.green
              : shortlisted
              ? AppColors.indigo
              : AppColors.amber,
        ),
      ),
    );
  }
}

class WorkerCard extends StatelessWidget {
  const WorkerCard({super.key, required this.worker, this.onTap});
  final Worker worker;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.brand100,
                  child: Text(
                    worker.initials,
                    style: const TextStyle(
                      color: AppColors.brandDark,
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
                          const Icon(
                            LucideIcons.badgeCheck,
                            size: 17,
                            color: AppColors.green,
                          ),
                        ],
                      ),
                      Text(
                        '${worker.trade} · ${worker.experience} yrs exp · ★ ${worker.rating}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '⌖ ${worker.distance} km     ₹${worker.wage}/day',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(worker.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: worker.skills
                  .map((s) => BrandChip(s, neutral: true))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField(
    this.label, {
    super.key,
    this.hint,
    this.lines = 1,
    this.keyboardType,
    this.controller,
  });
  final String label;
  final String? hint;
  final int lines;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
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
          maxLines: lines,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );
}
