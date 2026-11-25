import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  String? token;
  VoidCallback? onUnauthorized;
  /// Deployed backend on Render (biletflow/render.yaml, service "biletflow-api").
  /// Render's free tier sleeps when idle; waking it can take ~50 seconds.
  static const requestTimeout = Duration(seconds: 60);

  static const productionBaseUrl = 'https://biletflow-api.onrender.com/api/v1';

  /// Production by default. Override with --dart-define=API_BASE_URL=<url>, or use
  /// --dart-define=API_BASE_URL=local for a backend on this computer
  /// (127.0.0.1, or 10.0.2.2 from the Android emulator).
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured == 'local') {
      final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1';
      return 'http://$host:8000/api/v1';
    }
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/$'), '');
    }
    return productionBaseUrl;
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
  Future<Uint8List> download(String path) async {
    final sessionToken = token;
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(requestTimeout);
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            sessionToken != null &&
            token == sessionToken) {
          onUnauthorized?.call();
        }
        throw ApiException(
            'Download failed (${response.statusCode}).', response.statusCode);
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on http.ClientException {
      throw const ApiException(
          'Cannot download the ticket. Check your connection.');
    }
  }

  Future<dynamic> request(String method, String path,
      {Object? body, String? idempotencyKey}) async {
    final sessionToken = token;
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll(headers);
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      final response =
          await http.Response.fromStream(await _client.send(request))
              .timeout(requestTimeout);
      if (response.statusCode == 401 &&
          sessionToken != null &&
          token == sessionToken) {
        onUnauthorized?.call();
      }
      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } on FormatException {
          throw ApiException(
              'The server returned an unreadable response (${response.statusCode}). Please retry.',
              response.statusCode);
        }
      }
      if (response.statusCode >= 400) {
        final detail = data is Map ? data['detail'] : null;
        final message = detail is List
            ? detail
                .map((e) =>
                    '${(e['loc'] as List).skip(1).join('.')}: ${e['msg']}')
                .join('\n')
            : detail?.toString() ?? 'Request failed (${response.statusCode}).';
        throw ApiException(message, response.statusCode);
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
          'The server took too long to respond. Please retry.');
    } on http.ClientException {
      throw ApiException(
          'Cannot reach the backend at $baseUrl. Check your connection.');
    }
  }
}
