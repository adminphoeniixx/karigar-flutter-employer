import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:employer_kariger_app/screens/profile/plans_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/models/api_models.dart';
import 'package:employer_kariger_app/screens/workers/contacts_view.dart';
import 'package:employer_kariger_app/screens/workers/workers_screen.dart';
import 'billing_drafts_test.dart' show harness, service, jsonResponse;

void main() {
  testWidgets(
    'plans render all server plans without showing a stale payment error',
    (tester) async {
      const channel = MethodChannel('razorpay_flutter');
      var recovered = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'resync' && !recovered) {
          recovered = true;
          return {
            'type': 1,
            'data': {'code': 0, 'message': 'undefined'},
          };
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final api = service(
        (_) async => jsonResponse({
          'plans': [
            for (final name in ['Basic', 'Standard', 'Pro', 'Enterprise'])
              {
                'name': name,
                'price': 499,
                'purchasable': false,
                'feature_list': ['$name contact allowance'],
              },
          ],
        }),
      );
      await tester.pumpWidget(harness(api, const PlansScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      for (final name in ['Basic', 'Standard', 'Pro', 'Enterprise']) {
        await tester.scrollUntilVisible(
          find.text('$name contact allowance'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('$name contact allowance'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  test('unlock uses profile ID and preserves business error code', () async {
    final api = service((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/employer/workers/41/unlock');
      return jsonResponse({
        'message': 'undefined',
        'code': 'unlock_limit_reached',
      }, 422);
    });
    await expectLater(
      api.unlockWorker(41),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'unlock_limit_reached')
            .having((e) => e.message, 'message', isNot('undefined')),
      ),
    );
  });
  test(
    'contact permissions and cycle renewal parse independently of phone',
    () {
      final worker = WorkerProfile.fromJson({
        'id': 41,
        'user_id': 88,
        'can_unlock': true,
        'contact_unlocked': false,
        'phone': null,
      });
      expect(worker.canUnlock, isTrue);
      expect(worker.contactUnlocked, isFalse);
      expect(worker.locked, isTrue);
      final credits = UnlockSummary.fromJson({
        'unmetered': true,
        'plan_remaining': null,
        'unlocks_reset_at': '2026-10-02T07:14:09Z',
      });
      expect(credits.unmetered, isTrue);
      expect(credits.unlocksResetAt?.month, 10);
    },
  );
  testWidgets(
    'contacts paginate, search from first page, and fit narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Uri>[];
      final api = service((request) async {
        requests.add(request.url);
        final page = request.url.queryParameters['page'] ?? '1';
        return jsonResponse({
          'contacts': {
            'data': [
              {
                'profile_id': 41,
                'worker_id': 88,
                'name': 'Worker $page',
                'phone': '9876543210',
                'email': 'worker@example.com',
                'skills': ['Electrical Wiring', 'Waterproofing', 'Carpentry'],
              },
            ],
            'last_page': 2,
          },
          'usage': {
            'plan': 'Standard',
            'limit': 60,
            'used': 2,
            'remaining': 58,
            'used_database': 1,
            'used_applicants': 1,
            'database_total': 2,
            'applicants_total': 1,
          },
        });
      });
      await tester.pumpWidget(
        harness(
          api,
          Scaffold(
            body: ContactsView(source: 'database', onUsage: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Worker 1'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Load more'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['page'], '2');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'Meena');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['q'], 'Meena');
      expect(requests.last.queryParameters['page'], '1');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('directory unlock refreshes contact and counts', (tester) async {
    bool unlocked = false;
    final api = service((request) async {
      if (request.method == 'POST') {
        expect(request.url.path, '/api/v1/employer/workers/41/unlock');
        unlocked = true;
        return jsonResponse({
          'worker': {'phone': '9876543210'},
        });
      }
      if (request.url.path.endsWith('dashboard')) return jsonResponse({});
      return jsonResponse({
        'workers': {
          'data': [
            {
              'id': 41,
              'user_id': 88,
              'name': 'Meena Devi',
              'skills': ['Weaving'],
              'can_unlock': !unlocked,
              'contact_unlocked': unlocked,
              'phone': unlocked ? '9876543210' : null,
            },
          ],
          'total': 1,
        },
        'contact_counts': {
          'database_total': unlocked ? 1 : 0,
          'applicants_total': 0,
        },
      });
    });
    await tester.pumpWidget(harness(api, const WorkersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock contact'));
    await tester.pumpAndSettle();
    expect(unlocked, isTrue);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Database contacts (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
