import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/screens/dashboard/main_shell.dart';
import 'package:employer_kariger_app/widgets/location_map.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int step = 0;
  String hiringAs = 'Business / Company';
  String companySize = '11\u201350';
  final selectedTrades = <String>{};

  static const trades = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Masonry',
    'AC Repair',
    'Welding',
    'Driving',
    'Housekeeping',
    'Helper',
    'Fabrication',
    'Tiling',
  ];

  void _next() {
    if (step < 4) {
      setState(() => step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (step > 0) {
      setState(() => step--);
    } else {
      Navigator.maybePop(context);
    }
  }

  void _finish() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const MainShell()),
    (_) => false,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: step == 0
          ? const SizedBox.shrink()
          : IconButton(
              onPressed: _back,
              icon: const Icon(LucideIcons.arrowLeft),
            ),
      leadingWidth: 44,
      title: const Text('Set up your business'),
      actions: [
        Center(
          child: Text(
            '${step + 1}/5',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (step + 1) / 5,
            child: Container(height: 4, color: AppColors.primary),
          ),
        ),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
            children: [_stepContent()],
          ),
        ),
        _bottomBar(),
      ],
    ),
  );

  Widget _stepContent() {
    switch (step) {
      case 0:
        return _section(
          title: 'Who are you hiring as?',
          subtitle: 'Workers will see this contact name on your jobs.',
          children: [
            const _FieldLabel('Your full name'),
            const _Input(hint: 'e.g. Anil Sharma'),
            const SizedBox(height: 16),
            const _FieldLabel('You are hiring as'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Business / Company', 'Contractor', 'Individual / Household']
                  .map(
                    (item) => _SelectChip(
                      text: item,
                      selected: hiringAs == item,
                      onTap: () => setState(() => hiringAs = item),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case 1:
        return _section(
          title: 'Tell us about your business',
          subtitle: 'This appears on your public employer profile.',
          children: [
            const _FieldLabel('Business / Company name'),
            const _Input(hint: 'e.g. Sri Sai Constructions'),
            const SizedBox(height: 16),
            const _FieldLabel('Industry'),
            const _SelectBox(hint: 'Select industry'),
            const SizedBox(height: 16),
            const _FieldLabel('Company size'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                '1\u201310',
                '11\u201350',
                '51\u2013200',
                '200+',
              ]
                  .map(
                    (item) => _SelectChip(
                      text: item,
                      selected: companySize == item,
                      onTap: () => setState(() => companySize = item),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case 2:
        return _section(
          title: 'Where are you based?',
          subtitle: "We'll show your jobs to workers near this location.",
          children: [
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.brand50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.locateFixed, size: 19, color: AppColors.primary),
                  SizedBox(width: 9),
                  Text(
                    'Use my current location',
                    style: TextStyle(
                      color: AppColors.brandDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _FieldLabel('State'),
            const _SelectBox(hint: 'Select state'),
            const SizedBox(height: 16),
            const _FieldLabel('City / District'),
            const _SelectBox(hint: 'Select city'),
            const SizedBox(height: 16),
            const _FieldLabel('Pin your work location'),
            const SizedBox(height: 150, child: LocationMap()),
          ],
        );
      case 3:
        return _section(
          title: 'What kind of workers do you hire?',
          subtitle:
              "Pick the trades you usually need. We'll suggest matching workers. Choose all that apply.",
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 9,
              children: trades
                  .map(
                    (item) => _SelectChip(
                      text: item,
                      selected: selectedTrades.contains(item),
                      onTap: () => setState(() {
                        selectedTrades.contains(item)
                            ? selectedTrades.remove(item)
                            : selectedTrades.add(item);
                      }),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      default:
        return _section(
          title: 'Verify your business',
          titleTrailing: const _OptionalPill(),
          subtitle:
              'Add GST / PAN to get a Verified Employer badge — verified employers get 3x more applications and rank higher. You can skip and do this later.',
          subtitleWidget: const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Add GST / PAN to get a '),
                TextSpan(
                  text: 'Verified Employer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      ' badge — verified employers get 3x more applications and rank higher. You can skip and do this later.',
                ),
              ],
            ),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          children: [
            const _FieldLabel('GST number (optional)'),
            const _Input(hint: '22ABCDE1234F1Z5'),
            const SizedBox(height: 16),
            const _FieldLabel('Business PAN'),
            const _Input(hint: 'ABCDE1234F'),
            const SizedBox(height: 16),
            CustomPaint(
              painter: _DashedBorderPainter(),
              child: Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.upload, color: AppColors.primary, size: 22),
                    SizedBox(height: 7),
                    Text(
                      'Upload GST / registration proof',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'JPG / PNG / PDF · max 5MB',
                      style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(LucideIcons.shield, color: AppColors.green, size: 16),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Documents are encrypted and used only for verification.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _section({
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? titleTrailing,
    Widget? subtitleWidget,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
          ),
          if (titleTrailing != null) titleTrailing,
        ],
      ),
      const SizedBox(height: 7),
      subtitleWidget ??
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
      const SizedBox(height: 20),
      ...children,
    ],
  );

  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 11, 16, 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: step == 4
        ? Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _finish,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _finish,
                  child: const Text('Verify & Finish'),
                ),
              ),
            ],
          )
        : FilledButton(onPressed: _next, child: const Text('Continue')),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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
  const _Input({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: TextField(decoration: InputDecoration(hintText: hint)),
  );
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(child: Text(hint, style: const TextStyle(fontSize: 14))),
        const Icon(LucideIcons.chevronDown, size: 17),
      ],
    ),
  );
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
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
          color: selected ? AppColors.brand200 : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? AppColors.brandDark : AppColors.muted,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _OptionalPill extends StatelessWidget {
  const _OptionalPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.line2,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Optional',
      style: TextStyle(fontSize: 11, color: AppColors.muted),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(14);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          radius,
        ),
      );
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    for (double start = 0; start < metric.length; start += dash + gap) {
      canvas.drawPath(
        metric.extractPath(start, (start + dash).clamp(0, metric.length)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
