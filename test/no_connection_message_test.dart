import 'dart:io';

import 'package:employer_kariger_app/core/api/api_client.dart';
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:employer_kariger_app/core/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<String> messageWhen(Object failure) async {
  final client = ApiClient(client: MockClient((_) async => throw failure));
  try {
    await client.get('/employer/jobs');
  } on ApiException catch (exception) {
    return exception.message;
  }
  fail('the request should have failed');
}

void main() {
  test('no internet reads the same plain message, whichever way it fails', () async {
    // On a phone, "no internet" arrives as either of these.
    final socket = await messageWhen(
      const SocketException('Failed host lookup: superkarigar.com'),
    );
    final wrapped = await messageWhen(
      http.ClientException('SocketException: Failed host lookup'),
    );

    expect(socket, noConnectionMessage);
    expect(wrapped, noConnectionMessage);
    expect(noConnectionMessage, isNot(contains('API')));
  });

  testWidgets('the message reads in Hindi', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: const [Locale('en'), Locale('hi')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      AppStrings.text(captured, noConnectionMessage),
      'इंटरनेट कनेक्शन नहीं है। इंटरनेट जांचें और फिर कोशिश करें।',
    );
  });
}
