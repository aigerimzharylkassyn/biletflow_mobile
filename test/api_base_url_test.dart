import 'package:biletflow_mobile/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const configured = String.fromEnvironment('API_BASE_URL');
  final usesLocal = configured.isEmpty || configured == 'local';

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android reaches the local backend through the emulator host', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ApiClient.baseUrl,
      usesLocal
          ? 'http://10.0.2.2:8000/api/v1'
          : configured.replaceFirst(RegExp(r'/$'), ''),
    );
  });

  test('iOS reaches the local backend through loopback', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      ApiClient.baseUrl,
      usesLocal
          ? 'http://127.0.0.1:8000/api/v1'
          : configured.replaceFirst(RegExp(r'/$'), ''),
    );
  });
}
