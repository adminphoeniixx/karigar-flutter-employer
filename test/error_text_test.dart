import 'dart:async';

import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an API error shows the server message', () {
    expect(
      errorText(const ApiException('Your plan has ended.', statusCode: 402)),
      'Your plan has ended.',
    );
  });

  test('a FormatException shows its sentence, without the type name', () {
    final text = errorText(
      const FormatException('Payment details are missing. Please try again.'),
    );

    expect(text, 'Payment details are missing. Please try again.');
    expect(text, isNot(contains('FormatException')));
  });

  test('a FormatException without a message falls back', () {
    expect(
      errorText(const FormatException(''), fallback: 'Try again.'),
      'Try again.',
    );
  });

  test('a timeout says the server is slow', () {
    expect(
      errorText(TimeoutException('x')),
      'The server is taking too long. Please try again.',
    );
  });

  test('anything else never shows Dart internals', () {
    final text = errorText(TypeError());

    expect(text, 'Something went wrong. Please try again.');
  });
}
