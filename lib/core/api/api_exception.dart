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
