import 'package:employer_kariger_app/core/dialog_controllers.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/profile/kyc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing_drafts_test.dart' show harness, service, jsonResponse;

Applicant applicant(String stage, String status) => Applicant.fromJson({
  'id': 1,
  'stage': stage,
  'status': status,
  'status_label': status == 'accepted' ? 'Accepted' : 'Pending',
  'worker': {'id': 2, 'name': 'Ramesh'},
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('31: the badge shows the hiring stage, not the raw status', () {
    // A shortlisted karigar's application status is still "pending".
    expect(applicant('shortlisted', 'pending').stageLabel, 'Shortlisted');
    expect(applicant('interview', 'pending').stageLabel, 'Interview');
    expect(applicant('hired', 'accepted').stageLabel, 'Hired');
    expect(applicant('rejected', 'rejected').stageLabel, 'Rejected');
    expect(applicant('pending', 'pending').stageLabel, 'Pending');
    expect(applicant('shortlisted', 'withdrawn').stageLabel, 'Withdrawn');
  });

  testWidgets('52: closing a dialog with a focused, filled field does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final wage = TextEditingController();
                await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    content: TextField(controller: wage, autofocus: true),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Send offer'),
                      ),
                    ],
                  ),
                );
                disposeAfterClose([wage]);
              },
              child: const Text('Hire'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hire'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '18000');
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();
    await tester.pump(dialogExitTime);

    expect(tester.takeException(), isNull);
    expect(find.text('Hire'), findsOneWidget);
  });

  testWidgets('30: a verified business sees what it sent, not an empty form', (
    tester,
  ) async {
    final api = service((request) async {
      if (request.url.path.endsWith('/reference')) {
        return jsonResponse({
          'verification': {
            'business_types': [
              {'key': 'proprietorship', 'label': 'Proprietorship'},
            ],
            'documents': [],
          },
        });
      }
      return jsonResponse({
        'business': {'business_type': null, 'legal_name': null},
        'gstin': '33AABCT1332L1ZU',
        'kyc': {
          'status': 'verified',
          'status_label': 'Verified',
          'business_type': 'proprietorship',
          'documents': [
            {'type': 'pan', 'label': 'PAN card', 'missing': false, 'has_file': true},
            {
              'type': 'gst',
              'label': 'GST certificate',
              'missing': false,
              'number': '33AABCT1332L1ZU',
            },
          ],
        },
        'digilocker': {},
      });
    });
    await tester.pumpWidget(harness(api, const KycScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Your business is verified. You can post jobs.'), findsOneWidget);
    expect(find.text('Proprietorship'), findsOneWidget);
    expect(find.text('PAN card'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    expect(find.text('Submit your details for review.'), findsNothing);
  });
}
