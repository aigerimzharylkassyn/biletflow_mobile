import 'dart:convert';
import 'dart:math';
import 'api_client.dart';

/// Retains submission keys after uncertain failures; a successful send starts a new intent.
class SupportService {
  SupportService(this.api);
  final ApiClient api;
  final _keys = <String, (String, String)>{};
  String _key(String action, Object body) {
    final signature = jsonEncode(body);
    if (_keys[action]?.$1 != signature) {
      _keys[action] = (
        signature,
        base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)))
      );
    }
    return _keys[action]!.$2;
  }

  Future<dynamic> create(Map<String, dynamic> body) async {
    final result = await api.request('POST', '/support/cases',
        body: body, idempotencyKey: _key('create', body));
    _keys.remove('create');
    return result;
  }

  Future<void> reply(String id, String text) async {
    final body = {'body': text};
    await api.request('POST', '/support/cases/$id/messages',
        body: body, idempotencyKey: _key(id, body));
    _keys.remove(id);
  }
}
