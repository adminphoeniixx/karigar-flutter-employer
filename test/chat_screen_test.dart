import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/app_scope.dart';
import 'package:employer_kariger_app/core/data.dart';
import 'package:employer_kariger_app/screens/messages/chat_screen.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const worker = Worker('Ramesh', 'Tailor', 4, 4.5, 2.0, 15000, ['Stitching']);

Map<String, dynamic> message(int id, String body, {bool mine = false}) => {
  'id': id,
  'body': body,
  'sent_by_me': mine,
};

/// The thread endpoint's answer: newest page first, each page oldest first.
http.Response thread(List<Map<String, dynamic>> rows, {int lastPage = 1}) =>
    http.Response(
      jsonEncode({
        'messages': rows,
        'meta': {'current_page': 1, 'last_page': lastPage},
      }),
      200,
    );

Future<void> openChat(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) server,
) async {
  final api = EmployerApiService(ApiClient(client: MockClient(server)));
  await tester.pumpWidget(
    AppScope(
      api: api,
      auth: AuthController(api),
      dashboard: DashboardController(api),
      jobs: JobsController(api),
      workers: WorkersController(api),
      profile: ProfileController(api),
      child: const MaterialApp(
        home: ChatScreen(worker: worker, conversationId: 9),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a failed first load shows the error and Retry works', (
    tester,
  ) async {
    var calls = 0;
    await openChat(tester, (request) async {
      calls++;
      return calls == 1
          ? http.Response(jsonEncode({'message': 'Server busy'}), 500)
          : thread([message(1, 'Namaste ji')]);
    });

    expect(find.text('Server busy'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Namaste ji'), findsOneWidget);
  });

  testWidgets('a message that fails to send says so and keeps the text', (
    tester,
  ) async {
    await openChat(tester, (request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'message': 'No internet'}), 503);
      }
      return thread([message(1, 'Namaste ji')]);
    });

    await tester.enterText(find.byType(TextField), 'Kal aa sakte ho?');
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Message not sent'), findsOneWidget);
    expect(find.text('Kal aa sakte ho?'), findsOneWidget);
  });

  testWidgets('a reply from the karigar shows without reopening the chat', (
    tester,
  ) async {
    var rows = [message(1, 'Namaste ji')];
    await openChat(tester, (request) async => thread(rows));
    expect(find.text('Haan, kal aa jaunga'), findsNothing);

    rows = [...rows, message(2, 'Haan, kal aa jaunga')];
    await tester.pump(ChatScreen.pollEvery);
    await tester.pump();

    expect(find.text('Namaste ji'), findsOneWidget);
    expect(find.text('Haan, kal aa jaunga'), findsOneWidget);
  });

  testWidgets('earlier messages load on request, without duplicates', (
    tester,
  ) async {
    await openChat(tester, (request) async {
      final page = request.url.queryParameters['page'];
      return page == '2'
          ? thread([message(1, 'Pehla message'), message(2, 'Doosra')])
          : thread([message(2, 'Doosra'), message(3, 'Teesra')], lastPage: 2);
    });

    expect(find.text('Pehla message'), findsNothing);

    await tester.tap(find.text('Load earlier messages'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Pehla message'), findsOneWidget);
    expect(find.text('Doosra'), findsOneWidget);
    expect(find.text('Load earlier messages'), findsNothing);
  });

  testWidgets('the header names the job, never a made-up "Online"', (
    tester,
  ) async {
    await openChat(
      tester,
      (request) async => http.Response(
        jsonEncode({
          'conversation': {
            'id': 9,
            'job': {'id': 167, 'title': 'Tailor for boutique'},
          },
          'messages': [message(1, 'Namaste ji')],
          'meta': {'current_page': 1, 'last_page': 1},
        }),
        200,
      ),
    );

    expect(find.text('Online'), findsNothing);
    expect(find.text('Tailor for boutique'), findsOneWidget);
  });
}
