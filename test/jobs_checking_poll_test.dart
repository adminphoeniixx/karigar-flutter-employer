import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/screens/jobs/jobs_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A server whose one job stays in the safety check; counts list requests.
class CheckingServer {
  int listCalls = 0;
  String status = 'checking';

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/api/v1/employer/jobs') listCalls++;
    return http.Response(
      jsonEncode({
        'data': [
          {
            'id': 1,
            'title': 'Tailor',
            'category': 'Tailoring',
            'status': 'active',
            'moderation': {'status': status},
          },
        ],
      }),
      200,
    );
  }
}

/// [JobsScreen] as the bottom bar has it: tab [index] of an IndexedStack,
/// My Jobs being tab 0.
Widget shell(CheckingServer server, ValueNotifier<int> index) {
  final api = EmployerApiService(
    ApiClient(client: MockClient(server.handle)),
  );
  return AppScope(
    api: api,
    auth: AuthController(api),
    dashboard: DashboardController(api),
    jobs: JobsController(api),
    workers: WorkersController(api),
    profile: ProfileController(api),
    child: MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: index,
        builder: (_, value, _) => IndexedStack(
          index: value,
          children: const [JobsScreen(), Scaffold(body: Text('Karigars'))],
        ),
      ),
    ),
  );
}

Future<void> wait(WidgetTester tester, Duration duration) async {
  for (var left = duration; left > Duration.zero; left -= JobsScreen.checkEvery) {
    await tester.pump(JobsScreen.checkEvery);
  }
  await tester.pump();
}

void main() {
  testWidgets('asks again while a job is checking and the list is shown', (
    tester,
  ) async {
    final server = CheckingServer();
    await tester.pumpWidget(shell(server, ValueNotifier(0)));
    await tester.pump();
    final afterFirstLoad = server.listCalls;

    await wait(tester, const Duration(seconds: 30));

    expect(server.listCalls - afterFirstLoad, greaterThanOrEqualTo(5));
  });

  testWidgets('stops once the job is no longer checking', (tester) async {
    final server = CheckingServer();
    await tester.pumpWidget(shell(server, ValueNotifier(0)));
    await tester.pump();
    server.status = 'approved';
    await wait(tester, const Duration(seconds: 10));
    final settled = server.listCalls;

    await wait(tester, const Duration(seconds: 60));

    expect(server.listCalls, settled);
  });

  testWidgets('a hidden tab does not ask, and asks again when shown', (
    tester,
  ) async {
    final server = CheckingServer();
    final index = ValueNotifier(0);
    await tester.pumpWidget(shell(server, index));
    await tester.pump();

    index.value = 1; // the employer moves to the Karigars tab
    await tester.pump();
    final hiddenFrom = server.listCalls;
    await wait(tester, const Duration(seconds: 60));
    expect(server.listCalls, hiddenFrom);

    index.value = 0; // back to My Jobs: one look straight away, then polling
    await tester.pump();
    await tester.pump();
    expect(server.listCalls, hiddenFrom + 1);
    await wait(tester, const Duration(seconds: 20));
    expect(server.listCalls, greaterThan(hiddenFrom + 1));
  });

  testWidgets('gives up after the check window, until the employer is back', (
    tester,
  ) async {
    final server = CheckingServer();
    final index = ValueNotifier(0);
    await tester.pumpWidget(shell(server, index));
    await tester.pump();

    await wait(tester, JobsScreen.checkFor + const Duration(seconds: 10));
    final gaveUpAt = server.listCalls;
    await wait(tester, const Duration(minutes: 2));
    expect(server.listCalls, gaveUpAt);

    index.value = 1;
    await tester.pump();
    index.value = 0;
    await tester.pump();
    await wait(tester, const Duration(seconds: 20));
    expect(server.listCalls, greaterThan(gaveUpAt));
  });
}
