import 'package:employer_kariger_app/core/push/push_router.dart';
import 'package:employer_kariger_app/core/theme.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(String, Color?)> pill(WidgetTester tester, String status) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: StatusPill(status))),
    ),
  );
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(StatusPill), matching: find.byType(Text)),
  );
  final box = tester.widget<Container>(
    find.descendant(of: find.byType(StatusPill), matching: find.byType(Container)),
  );
  return (text.data!, (box.decoration as BoxDecoration).color);
}

EmployerJob job(Map<String, dynamic> json) => EmployerJob.fromJson({
  'id': 1,
  'title': 'Tailor',
  'category': 'Tailoring',
  ...json,
});

void main() {
  testWidgets('"active" from the API and "Active" look the same, in green', (
    tester,
  ) async {
    final lower = await pill(tester, 'active');
    final upper = await pill(tester, 'Active');

    expect(lower.$1, 'Active');
    expect(upper.$1, 'Active');
    expect(lower.$2, AppColors.greenBg);
    expect(upper.$2, AppColors.greenBg);
  });

  testWidgets('closed reads as closed, not live', (tester) async {
    final closed = await pill(tester, 'closed');

    expect(closed.$1, 'Closed');
    expect(closed.$2, isNot(AppColors.greenBg));
  });

  test('a job badge shows its safety check first, then its status', () {
    expect(jobStatusLabel(job({'status': 'active'})), 'Active');
    expect(jobStatusLabel(job({'status': 'closed'})), 'Closed');
    expect(
      jobStatusLabel(
        job({
          'status': 'active',
          'moderation': {'status': 'pending'},
        }),
      ),
      'Under review',
    );
    expect(
      jobStatusLabel(
        job({
          'status': 'draft',
          'moderation': {'status': 'checking'},
        }),
      ),
      'Checking…',
    );
  });

  test('the job card carries the real views, not a made-up number', () {
    final card = jobCard(
      job({
        'status': 'active',
        'stats': {'views': 37, 'applicants': 3, 'shortlisted': 2, 'hired': 1},
      }),
    );

    expect(card.views, 37);
    expect(card.applied, 3);
    expect(card.status, 'Active');
  });
}
