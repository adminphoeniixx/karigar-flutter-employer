import 'dart:convert';
import 'dart:io';

import 'package:employer_kariger_app/controllers/auth_controller.dart';
import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/services/employer_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An app start with a saved token, where `/auth/me` answers with [handler].
Future<(AuthController, bool)> restoreWith(
  Future<http.Response> Function(http.Request) handler,
) async {
  SharedPreferences.setMockInitialValues({'employer_auth_token': 'saved'});
  final auth = AuthController(
    EmployerApiService(ApiClient(client: MockClient(handler))),
  );
  final restored = await auth.restore();
  return (auth, restored);
}

Future<String?> savedToken() async =>
    (await SharedPreferences.getInstance()).getString('employer_auth_token');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a valid token restores the session and the user', () async {
    final (auth, restored) = await restoreWith(
      (_) async => http.Response(
        jsonEncode({
          'user': {'id': 7, 'role': 'employer'},
        }),
        200,
      ),
    );

    expect(restored, isTrue);
    expect(auth.authenticated, isTrue);
    expect(auth.user?['id'], 7);
    expect(await savedToken(), 'saved');
  });

  test('a 401 signs the user out', () async {
    final (auth, restored) = await restoreWith(
      (_) async =>
          http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401),
    );

    expect(restored, isFalse);
    expect(auth.authenticated, isFalse);
    expect(await savedToken(), isNull);
  });

  test('no internet keeps the session', () async {
    final (auth, restored) = await restoreWith(
      (_) async => throw const SocketException('Network is unreachable'),
    );

    expect(restored, isTrue);
    expect(auth.authenticated, isTrue);
    expect(await savedToken(), 'saved');
  });

  for (final status in [403, 500, 503]) {
    test('a $status from the server keeps the session', () async {
      final (auth, restored) = await restoreWith(
        (_) async => http.Response(jsonEncode({'message': 'Oops'}), status),
      );

      expect(restored, isTrue);
      expect(auth.authenticated, isTrue);
      expect(await savedToken(), 'saved');
    });
  }

  test('a broken response body keeps the session', () async {
    final (auth, restored) = await restoreWith(
      (_) async => http.Response('<html>Bad gateway</html>', 200),
    );

    expect(restored, isTrue);
    expect(auth.authenticated, isTrue);
  });
}
