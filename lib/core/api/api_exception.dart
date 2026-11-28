import 'dart:async';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code, this.errors});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? errors;

  @override
  String toString() => message;
}

String readableMessage(
  String? message, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final value = message?.trim() ?? '';
  return value.isEmpty || ['undefined', 'null'].contains(value.toLowerCase())
      ? fallback
      : value;
}

/// The text to show the employer for any error: the server's message for an
/// API error, the plain sentence inside a FormatException, never a Dart type
/// name like "FormatException:" or "TypeError".
String errorText(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) => switch (error) {
  ApiException(:final message) => message,
  FormatException(:final message) => readableMessage(
    message,
    fallback: fallback,
  ),
  TimeoutException() => 'The server is taking too long. Please try again.',
  _ => fallback,
};
