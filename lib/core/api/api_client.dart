import 'dart:convert';
import 'dart:io';

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
    try {
      return _decode(await http.Response.fromStream(await request.send()));
    } on SocketException {
      throw const ApiException(
        'Server se connection nahi ho paaya. Internet aur API URL check karein.',
      );
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
    try {
      return _decode(
        await http.Response.fromStream(await _client.send(request)),
      );
    } on SocketException {
      throw const ApiException(
        'Server se connection nahi ho paaya. Internet aur API URL check karein.',
      );
    } on http.ClientException {
      throw const ApiException('Network request complete nahi ho saki.');
    }
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}');
    if (query == null) return uri;
    final values = <String, String>{};
    query.forEach((key, value) {
      if (value != null && '$value'.isNotEmpty) {
        values[key] = value is List ? value.join(',') : '$value';
      }
    });
    return uri.replace(queryParameters: values);
  }

  Map<String, String> _headers({bool json = true}) => {
    HttpHeaders.acceptHeader: 'application/json',
    if (json) HttpHeaders.contentTypeHeader: 'application/json',
    if (_token != null) HttpHeaders.authorizationHeader: 'Bearer $_token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    }
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

  void close() => _client.close();
}
