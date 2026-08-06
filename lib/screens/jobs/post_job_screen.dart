import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final selectedSkills = <String>{'Pipe Fitting'};
  final selectedPerks = <String>{};
  String shift = 'Day';
  String contact = 'Apply + Call';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Post a Job', style: TextStyle(fontSize: 16)),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const _Label('Job title'),
              const _Input(hint: 'e.g. Plumber for apartment project'),
              const SizedBox(height: 14),
              const _Label('Category'),
              const _Select('Select category'),
              const SizedBox(height: 14),
              const _Label('Skills required'),
              _chips(
                ['Pipe Fitting', 'Waterproofing', 'Drainage', 'Testing'],
                selectedSkills,
                multi: true,
              ),
              const _Hint(
                'Tap to add. Workers with these skills are matched first.',
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_Label('Openings'), _Input(hint: '3')],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Min experience'),
                        _Input(hint: '1', suffix: 'yrs'),
                      ],
                    ),
                  ),
                ],
              ),
              const _SectionLabel('Wage'),
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Min ₹'),
                        _Input(hint: '800', prefix: '₹'),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Max ₹'),
                        _Input(hint: '1000', prefix: '₹'),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 88,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_Label('Per'), _Select('day')],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _Label('Shift'),
              _singleChips(['Day', 'Night', 'Rotational', 'Flexible'], shift, (
                value,
              ) {
                setState(() => shift = value);
              }),
              const SizedBox(height: 14),
              const _Label('Perks & benefits'),
              _chips(
                ['Food', 'Stay', 'Travel', 'Tools provided'],
                selectedPerks,
                multi: true,
              ),
              const SizedBox(height: 14),
              const _Label('Job description'),
              const _Input(
                hint: 'Describe the work, site details, duration, tools provided…',
                lines: 4,
              ),
              const _SectionLabel('Location'),
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_Label('State'), _Select('Tamil Nadu')],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_Label('City'), _Select('Chennai')],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _Label('Pin the job location'),
              const SizedBox(height: 150, child: LocationMap()),
              const SizedBox(height: 14),
              const _Label('How should workers reach you?'),
              _singleChips(
                ['Apply + Call', 'Apply only', 'Call only'],
                contact,
                (value) => setState(() => contact = value),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: const Text('Save draft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Publish Job'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chips(List<String> values, Set<String> selected, {required bool multi}) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (value) => _Choice(
                text: value,
                selected: selected.contains(value),
                onTap: () => setState(() {
                  selected.contains(value)
                      ? selected.remove(value)
                      : selected.add(value);
                }),
              ),
            )
            .toList(),
      );

  Widget _singleChips(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (value) => _Choice(
            text: value,
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
        )
        .toList(),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.hint,
    this.lines = 1,
    this.prefix,
    this.suffix,
  });
  final String hint;
  final int lines;
  final String? prefix;
  final String? suffix;
  @override
  Widget build(BuildContext context) => TextField(
    maxLines: lines,
    decoration: InputDecoration(
      hintText: hint,
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      prefixIcon: prefix == null ? null : Center(widthFactor: 1, child: Text(prefix!)),
      suffixIcon: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  suffix!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
    ),
  );
}

class _Select extends StatelessWidget {
  const _Select(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        const Icon(LucideIcons.chevronDown, size: 16),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final String text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand50 : Colors.white,
        border: Border.all(
          color: selected ? AppColors.brand100 : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? AppColors.brandDark : AppColors.muted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}
