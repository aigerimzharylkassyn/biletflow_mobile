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
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured.replaceFirst(RegExp(r'/$'), '');
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2' : '127.0.0.1';
    return 'http://$host:8000/api/v1';
  }
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  Future<dynamic> request(String method, String path, {Object? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await http.Response.fromStream(await _client.send(request))
          .timeout(const Duration(seconds: 20));
      final dynamic data = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && token != null) onUnauthorized?.call();
        final detail = data is Map ? data['detail'] : null;
        final message = detail is List
            ? detail.map((e) => '${(e['loc'] as List).skip(1).join('.')}: ${e['msg']}').join('\n')
            : detail?.toString() ?? 'Request failed (${response.statusCode}).';
        throw ApiException(message, response.statusCode);
      }
      return data;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond. Please retry.');
    } on http.ClientException {
      throw ApiException('Cannot reach the backend at $baseUrl. Check your connection.');
    }
  }
}
