import 'package:employer_kariger_app/screens/workers/workers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'billing_drafts_test.dart' show harness, service, jsonResponse;

/// A fake server that records each path asked for. The Find list holds
/// "Find karigar"; the Rejected list (rejected=1) is empty.
({List<Uri> requests, Future<http.Response> Function(http.Request) handler})
fakeServer() {
  final requests = <Uri>[];
  Future<http.Response> handler(http.Request request) async {
    requests.add(request.url);
    final path = request.url.path;
    if (path.endsWith('/reference')) {
      return jsonResponse({
        'job_categories': ['Weaving'],
      });
    }
    if (path.endsWith('/employer/workers')) {
      final rejected = request.url.queryParameters['rejected'] == '1';
      return jsonResponse({
        'workers': {
          'data': [
            if (!rejected)
              {
                'id': 1,
                'user_id': 9,
                'name': 'Find karigar',
                'skills': ['Weaving'],
              },
          ],
          'current_page': 1,
          'last_page': 1,
          'total': rejected ? 0 : 1,
        },
        'contact_counts': {
          'rejected_count': 0,
          'database_total': 0,
          'applicants_total': 0,
        },
      });
    }
    return jsonResponse({
      'contacts': {'data': [], 'current_page': 1, 'last_page': 1},
    });
  }

  return (requests: requests, handler: handler);
}

int workerLists(List<Uri> requests) =>
    requests.where((uri) => uri.path.endsWith('/employer/workers')).length;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('screens share one reference request; a failed one is asked again', () async {
    var calls = 0;
    var fail = true;
    final api = service((request) async {
      calls++;
      if (fail) return jsonResponse({'message': 'Server busy'}, 500);
      return jsonResponse({
        'job_categories': ['Weaving'],
      });
    });

    await expectLater(api.reference(), throwsA(anything));
    fail = false;
    final first = await api.reference();
    final second = await api.reference();

    expect(first['job_categories'], ['Weaving']);
    expect(identical(first, second), isTrue);
    expect(calls, 2);
  });

  testWidgets('the Karigars tab loads nothing until it is shown', (
    tester,
  ) async {
    final server = fakeServer();
    final api = service(server.handler);
    var shown = 0;
    late StateSetter show;
    await tester.pumpWidget(
      harness(
        api,
        StatefulBuilder(
          builder: (context, setState) {
            show = setState;
            return IndexedStack(
              index: shown,
              children: const [SizedBox(), WorkersScreen()],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(server.requests, isEmpty);

    show(() => shown = 1);
    await tester.pumpAndSettle();

    expect(workerLists(server.requests), 1);
    expect(find.text('Find karigar'), findsOneWidget);
  });

  testWidgets('opened on Applicants, the Find list waits for the Find tab', (
    tester,
  ) async {
    final server = fakeServer();
    await tester.pumpWidget(
      harness(service(server.handler), const WorkersScreen(initialTab: 2)),
    );
    await tester.pumpAndSettle();

    expect(workerLists(server.requests), 0);

    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    expect(workerLists(server.requests), 1);
    expect(find.text('Find karigar'), findsOneWidget);
  });

  testWidgets('going back to Find from Rejected shows the Find list again', (
    tester,
  ) async {
    final server = fakeServer();
    await tester.pumpWidget(
      harness(service(server.handler), const WorkersScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find karigar'), findsOneWidget);

    await tester.tap(find.textContaining('Rejected'));
    await tester.pumpAndSettle();
    expect(find.text('Find karigar'), findsNothing);

    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    expect(find.text('Find karigar'), findsOneWidget);
    expect(
      server.requests.last.queryParameters.containsKey('rejected'),
      isFalse,
    );
  });
}
