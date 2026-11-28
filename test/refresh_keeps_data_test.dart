import 'dart:convert';

import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A server that answers once, then is unreachable.
EmployerApiService flakyServer() {
  var calls = 0;
  return EmployerApiService(
    ApiClient(
      client: MockClient((request) async {
        if (++calls > 1) {
          throw http.ClientException('Network is unreachable', request.url);
        }
        final body = switch (request.url.path) {
          '/api/v1/employer/dashboard' => {
            'stats': {'active_jobs': 9},
          },
          _ => {
            'data': {'id': 1, 'company_name': 'Sri Sai Tailors'},
          },
        };
        return http.Response(jsonEncode(body), 200);
      }),
    ),
  );
}

void main() {
  test('a failed dashboard refresh keeps the last dashboard', () async {
    final dashboard = DashboardController(flakyServer());
    await dashboard.load();
    final shown = dashboard.data;
    expect(shown, isNotNull);

    await dashboard.load();

    expect(dashboard.data, same(shown));
    expect(dashboard.error, isNotNull);
  });

  test('a failed profile refresh keeps the last profile', () async {
    final profile = ProfileController(flakyServer());
    await profile.load();
    expect(profile.profile?.companyName, 'Sri Sai Tailors');

    await profile.load();

    expect(profile.profile?.companyName, 'Sri Sai Tailors');
    expect(profile.error, isNotNull);
  });

  test('a successful refresh clears the error', () async {
    var fail = true;
    final dashboard = DashboardController(
      EmployerApiService(
        ApiClient(
          client: MockClient((request) async {
            if (fail) throw http.ClientException('offline', request.url);
            return http.Response(jsonEncode({'stats': {}}), 200);
          }),
        ),
      ),
    );
    await dashboard.load();
    expect(dashboard.error, isNotNull);

    fail = false;
    await dashboard.load();

    expect(dashboard.error, isNull);
    expect(dashboard.data, isNotNull);
  });
}
