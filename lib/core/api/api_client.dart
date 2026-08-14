import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/api_constants.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? ApiConstants.baseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  static const _tokenKey = 'employer_auth_token';
  final http.Client _client;
  final String baseUrl;
  String? _token;

  Future<void> initialize() async {
    try {
      _token = (await SharedPreferences.getInstance()).getString(_tokenKey);
    } on PlatformException {
      // A newly added native plugin is unavailable until a full app restart.
      // Keep the app usable with an in-memory token during that run.
      _token = null;
    } on MissingPluginException {
      _token = null;
    }
  }

  bool get isAuthenticated => _token?.isNotEmpty == true;

  Future<void> setToken(String? token) async {
    _token = token;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (token == null || token.isEmpty) {
        await preferences.remove(_tokenKey);
      } else {
        await preferences.setString(_tokenKey, token);
      }
    } on PlatformException {
      // The current session still works; persistence resumes after restart.
    } on MissingPluginException {
      // The current session still works; persistence resumes after restart.
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('POST', path, body: body, query: query);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<Map<String, dynamic>> multipart(
    String path, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(_headers(json: false));
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value.path),
      );
    }
    _logRequest(
      'POST',
      request.url,
      body: fields,
      files: files.map(
        (field, file) =>
            MapEntry(field, file.path.split(Platform.pathSeparator).last),
      ),
    );
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.Response.fromStream(await request.send());
      stopwatch.stop();
      return _decode(response, elapsed: stopwatch.elapsed);
    } on SocketException catch (error) {
      _logNetworkError('POST', request.url, error);
      throw const ApiException(
        'Could not connect to the server. Check your internet connection and API URL.',
      );
    } on http.ClientException catch (error) {
      _logNetworkError('POST', request.url, error);
      throw const ApiException('The network request could not be completed.');
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers())
      ..body = body == null ? '' : jsonEncode(body);
    _logRequest(method, request.url, body: body);
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      stopwatch.stop();
      return _decode(response, elapsed: stopwatch.elapsed);
    } on SocketException catch (error) {
      _logNetworkError(method, request.url, error);
      throw const ApiException(
        'Could not connect to the server. Check your internet connection and API URL.',
      );
    } on http.ClientException catch (error) {
      _logNetworkError(method, request.url, error);
      throw const ApiException('The network request could not be completed.');
    }
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}');
    if (query == null) return uri;
    final values = <String, List<String>>{};
    query.forEach((key, value) {
      if (value is Iterable) {
        final items = value
            .where((item) => item != null && '$item'.isNotEmpty)
            .map((item) => '$item')
            .toList();
        if (items.isNotEmpty) {
          values[key.endsWith('[]') ? key : '$key[]'] = items;
        }
      } else if (value != null && '$value'.isNotEmpty) {
        values[key] = ['$value'];
      }
    });
    return uri.replace(queryParameters: values);
  }

  Map<String, String> _headers({bool json = true}) => {
    HttpHeaders.acceptHeader: 'application/json',
    if (json) HttpHeaders.contentTypeHeader: 'application/json',
    if (_token != null) HttpHeaders.authorizationHeader: 'Bearer $_token',
  };

  Map<String, dynamic> _decode(http.Response response, {Duration? elapsed}) {
    Map<String, dynamic> data = {};
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        data = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'data': decoded};
      }
    } on FormatException catch (error) {
      _logResponse(
        response,
        elapsed: elapsed,
        payload: response.body,
        decodeError: error,
      );
      throw const ApiException('The server returned an invalid response.');
    }
    _logResponse(response, elapsed: elapsed, payload: data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ??
            'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        code: data['code']?.toString(),
        errors: data['errors'] is Map
            ? Map<String, dynamic>.from(data['errors'] as Map)
            : null,
      );
    }
    return data;
  }

  void _logRequest(
    String method,
    Uri uri, {
    Object? body,
    Map<String, String>? files,
  }) {
    if (!kDebugMode) return;
    final buffer = StringBuffer()
      ..writeln('┌─ API REQUEST ─────────────────────────────')
      ..writeln('│ $method $uri');
    if (body != null) {
      buffer.writeln('│ Body: ${_pretty(_redact(body))}');
    }
    if (files != null && files.isNotEmpty) {
      buffer.writeln('│ Files: ${_pretty(files)}');
    }
    buffer.write('└──────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  void _logResponse(
    http.Response response, {
    Duration? elapsed,
    Object? payload,
    Object? decodeError,
  }) {
    if (!kDebugMode) return;
    final method = response.request?.method ?? 'HTTP';
    final uri = response.request?.url;
    final successful = response.statusCode >= 200 && response.statusCode < 300;
    final buffer = StringBuffer()
      ..writeln(
        '┌─ API ${successful ? 'RESPONSE' : 'ERROR'} ─────────────────────────────',
      )
      ..writeln('│ $method ${uri ?? ''}')
      ..writeln(
        '│ Status: ${response.statusCode}'
        '${elapsed == null ? '' : ' · ${elapsed.inMilliseconds} ms'}',
      );
    if (decodeError != null) {
      buffer.writeln('│ Decode error: $decodeError');
    }
    buffer
      ..writeln('│ Response: ${_pretty(_redact(payload))}')
      ..write('└──────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  void _logNetworkError(String method, Uri uri, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '┌─ API NETWORK ERROR ──────────────────────\n'
      '│ $method $uri\n'
      '│ $error\n'
      '└──────────────────────────────────────────',
    );
  }

  Object? _redact(Object? value, [String? parentKey]) {
    const sensitiveKeys = {
      'authorization',
      'token',
      'device_token',
      'otp',
      'api_key',
      'apikey',
      'razorpay_key',
      'razorpay_signature',
      'password',
      'secret',
    };
    final normalizedKey = parentKey?.toLowerCase().replaceAll('-', '_');
    if (normalizedKey != null &&
        (sensitiveKeys.contains(normalizedKey) ||
            normalizedKey.endsWith('_token') ||
            normalizedKey.endsWith('_secret') ||
            normalizedKey.endsWith('_signature'))) {
      return '[REDACTED]';
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _redact(item, '$key')));
    }
    if (value is Iterable) {
      return value.map((item) => _redact(item)).toList();
    }
    return value;
  }

  String _pretty(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return '$value';
    }
  }

  void close() => _client.close();
}
