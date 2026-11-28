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

/// No internet until [online] is set; then one live job.
class Network {
  bool online = false;
  int calls = 0;

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/api/v1/employer/jobs') calls++;
    if (!online) throw http.ClientException('offline', request.url);
    return http.Response(
      jsonEncode({
        'data': [
          {
            'id': 1,
            'title': 'Plumber for Anna Nagar site',
            'category': 'Plumbing',
            'status': 'active',
          },
        ],
      }),
      200,
    );
  }
}

Widget shell(Network network, ValueNotifier<int> tab) {
  final api = EmployerApiService(ApiClient(client: MockClient(network.handle)));
  return AppScope(
    api: api,
    auth: AuthController(api),
    dashboard: DashboardController(api),
    jobs: JobsController(api),
    workers: WorkersController(api),
    profile: ProfileController(api),
    child: MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (_, value, _) => IndexedStack(
          index: value,
          children: const [Scaffold(body: Text('Home')), JobsScreen()],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opening My Jobs after the internet is back loads the jobs', (
    tester,
  ) async {
    final network = Network();
    final tab = ValueNotifier(0); // the app starts on Home, offline
    await tester.pumpWidget(shell(network, tab));
    await tester.pump();
    await tester.pump();
    expect(network.calls, 1, reason: 'the hidden tab loads once, and fails');

    network.online = true;
    tab.value = 1; // the employer opens My Jobs
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(network.calls, 2);
    expect(find.text('Plumber for Anna Nagar site'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('coming back to the app retries a failed list', (tester) async {
    final network = Network();
    final tab = ValueNotifier(1); // My Jobs open, offline
    await tester.pumpWidget(shell(network, tab));
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);

    network.online = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Plumber for Anna Nagar site'), findsOneWidget);
  });

  testWidgets('a list that loaded fine is not fetched again on every visit', (
    tester,
  ) async {
    final network = Network()..online = true;
    final tab = ValueNotifier(1);
    await tester.pumpWidget(shell(network, tab));
    await tester.pump();
    await tester.pump();
    final loaded = network.calls;

    tab.value = 0;
    await tester.pump();
    tab.value = 1;
    await tester.pump();
    await tester.pump();

    expect(network.calls, loaded);
  });
}
