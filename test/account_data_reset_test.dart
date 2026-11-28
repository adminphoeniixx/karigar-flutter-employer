import 'dart:convert';

import 'package:employer_kariger_app/controllers/account_data_reset.dart';
import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/controllers/employer_controllers.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake server holding employer A's jobs, profile and dashboard.
http.Response serve(http.Request request) {
  final body = switch (request.url.path) {
    '/api/v1/auth/me' => {
      'user': {'id': 1, 'role': 'employer'},
    },
    '/api/v1/employer/jobs' => {
      'data': [
        {'id': 11, 'title': "Employer A's plumber job", 'status': 'active'},
      ],
    },
    '/api/v1/employer/profile' => {
      'data': {'id': 1, 'company_name': 'Employer A'},
    },
    '/api/v1/employer/dashboard' => {
      'stats': {'active_jobs': 1},
    },
    '/api/v1/employer/workers' => {
      'workers': {
        'data': [
          {'id': 5, 'name': 'Ramesh'},
        ],
        'total': 1,
        'current_page': 1,
        'last_page': 1,
      },
    },
    _ => <String, dynamic>{},
  };
  return http.Response(jsonEncode(body), 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthController auth;
  late DashboardController dashboard;
  late JobsController jobs;
  late WorkersController workers;
  late ProfileController profile;
  late AccountDataReset reset;

  /// Employer A, signed in from a saved token, with every list loaded.
  Future<void> signedInWithData() async {
    SharedPreferences.setMockInitialValues({'employer_auth_token': 'token-a'});
    final api = EmployerApiService(
      ApiClient(client: MockClient((request) async => serve(request))),
    );
    auth = AuthController(api);
    dashboard = DashboardController(api);
    jobs = JobsController(api);
    workers = WorkersController(api);
    profile = ProfileController(api);
    reset = AccountDataReset(auth, [
      dashboard.clear,
      jobs.clear,
      workers.clear,
      profile.clear,
    ]);
    expect(await auth.restore(), isTrue);
    await Future.wait([
      dashboard.load(),
      jobs.load(),
      workers.search(),
      profile.load(),
    ]);
    expect(jobs.items, isNotEmpty);
    expect(workers.items, isNotEmpty);
    expect(profile.profile, isNotNull);
    expect(dashboard.data, isNotNull);
  }

  void expectNothingLeft() {
    expect(jobs.items, isEmpty);
    expect(jobs.hasLoaded, isFalse);
    expect(workers.items, isEmpty);
    expect(profile.profile, isNull);
    expect(dashboard.data, isNull);
  }

  tearDown(() => reset.dispose());

  test('logging out drops the account data', () async {
    await signedInWithData();

    await auth.logout();

    expect(auth.authenticated, isFalse);
    expectNothingLeft();
  });

  test('a deleted account (token removed, then cleared) drops it', () async {
    await signedInWithData();

    await auth.api.client.setToken(null);
    auth.clearSession();

    expectNothingLeft();
  });

  test('activity while signed in keeps the data', () async {
    await signedInWithData();

    // OTP sends, profile reloads and the like notify the auth controller
    // without signing out.
    auth.notifyListeners();

    expect(jobs.items, isNotEmpty);
    expect(profile.profile, isNotNull);
  });
}
