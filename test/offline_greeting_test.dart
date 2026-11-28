import 'dart:convert';

import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

EmployerApiService online() => EmployerApiService(
  ApiClient(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({'greeting': 'Karigar Test Constructions', 'stats': {}}),
        200,
      ),
    ),
  ),
);

EmployerApiService offline() => EmployerApiService(
  ApiClient(
    client: MockClient(
      (request) async => throw http.ClientException('offline', request.url),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the business name is still known on an offline start', () async {
    await DashboardController(online()).load();

    // The next app start has no internet.
    final dashboard = DashboardController(offline());
    await dashboard.load();

    expect(dashboard.data, isNull);
    expect(dashboard.error, isNotNull);
    expect(dashboard.savedGreeting, 'Karigar Test Constructions');
  });

  test('signing out forgets the name', () async {
    final first = DashboardController(online());
    await first.load();

    first.clear();
    await Future<void>.delayed(Duration.zero);
    final next = DashboardController(offline());
    await next.load();

    expect(first.savedGreeting, isNull);
    expect(next.savedGreeting, isNull);
  });

  test('no saved name on a first, offline start', () async {
    final dashboard = DashboardController(offline());
    await dashboard.load();

    expect(dashboard.savedGreeting, isNull);
  });
}
