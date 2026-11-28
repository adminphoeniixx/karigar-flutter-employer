import 'dart:async';
import 'dart:convert';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const secret = '42|s3cr3tSanctumTokenValue';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logging in and calling the API never logs the token', () async {
    SharedPreferences.setMockInitialValues({});
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add('$message');
    addTearDown(() => debugPrint = originalDebugPrint);

    final api = EmployerApiService(
      ApiClient(
        client: MockClient((request) async {
          final body = switch (request.url.path) {
            '/api/v1/auth/otp/verify' => {
              'token': secret,
              'user': {'id': 1, 'role': 'employer'},
            },
            _ => {'ok': true},
          };
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
    final auth = AuthController(api);

    // print() goes to the zone, not debugPrint: catch it too.
    await runZoned(
      () async {
        expect(await auth.verifyOtp('9000000001', '1234'), isNotNull);
        await api.dashboard();
        await auth.logout();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );

    expect(logs, isNotEmpty, reason: 'the API calls should still be logged');
    expect(logs.where((line) => line.contains('s3cr3tSanctumTokenValue')), isEmpty);
    expect(logs.any((line) => line.contains('Bearer token sent')), isTrue);
  });
}
