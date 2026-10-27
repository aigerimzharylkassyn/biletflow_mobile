import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> translations(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final english = translations('en');
  final keys = english.keys.where((k) => !k.startsWith('@')).toSet();
  for (final locale in ['kk', 'ru']) {
    test('$locale translations retain every label and interpolation argument',
        () {
      final localized = translations(locale);
      expect(localized.keys.where((k) => !k.startsWith('@')).toSet(), keys);
      final placeholders = RegExp(r'\{(\w+)\}');
      for (final key in keys) {
        Set<String> arguments(String value) => placeholders
            .allMatches(value)
            .map((match) => match.group(1)!)
            .toSet();
        expect(arguments(localized[key] as String),
            arguments(english[key] as String),
            reason: key);
      }
    });
  }
  test('Kazakh uses Cyrillic except product names and technical identifiers',
      () {
    final kazakh = translations('kk');
    final identifiers =
        RegExp(r'BiletFlow|[\w.]+@[\w.]+|HTTPS?|UTC|DEMO|PDF|URL|KZT|QR|ID');
    for (final key in keys) {
      final text = (kazakh[key] as String)
          .replaceAll(RegExp(r'\{\w+\}'), '')
          .replaceAll(identifiers, '');
      expect(RegExp(r'[A-Za-z\u00c0-\u024f]').hasMatch(text), isFalse,
          reason: '$key contains Latin Kazakh: $text');
    }
  });
}
