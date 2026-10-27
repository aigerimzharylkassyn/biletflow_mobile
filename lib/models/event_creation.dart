import 'dart:convert';
import 'dart:math';
import 'event.dart';

String creationKey() =>
    base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)));
DateTime kazakhstanWallTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 5));
String kazakhstanTimestamp(DateTime wall) =>
    DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute)
        .subtract(const Duration(hours: 5))
        .toIso8601String();

class CreationValidation implements Exception {
  const CreationValidation(this.code);
  final String code;
}

int positiveWhole(String text) {
  final value = int.tryParse(text.trim());
  if (value == null || value < 1 || value > 9007199254740991) {
    throw const CreationValidation('quantity');
  }
  return value;
}

int kztMinor(String text) {
  if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(text.trim())) {
    throw const CreationValidation('price');
  }
  final parts = text.trim().replaceAll(',', '.').split('.');
  final amount = int.parse(parts.first) * 100 +
      int.parse(parts.length == 1 ? '0' : parts.last.padRight(2, '0'));
  if (amount > 9007199254740991) throw const CreationValidation('price');
  return amount;
}

class EventDraft {
  bool freeOnly = true;
  final fields = <String, String>{
    'title': '',
    'category': 'tech',
    'banner': '',
    'description': '',
    'venue': '',
    'address': '',
    'city': 'Almaty',
    'capacity': '100',
    'visibility': 'public',
    'refund': ''
  };
  final dates = <String, DateTime?>{
    'starts': null,
    'ends': null,
    'opens': null,
    'closes': null
  };
  Map<String, dynamic> body({DateTime? now}) {
    if (dates.values.any((d) => d == null)) {
      throw const CreationValidation('dates');
    }
    final start = DateTime.parse(kazakhstanTimestamp(dates['starts']!));
    if (!start.isAfter((now ?? DateTime.now()).toUtc())) {
      throw const CreationValidation('future');
    }
    if (!dates['ends']!.isAfter(dates['starts']!)) {
      throw const CreationValidation('end');
    }
    if (!dates['opens']!.isBefore(dates['closes']!) ||
        dates['closes']!.isAfter(dates['starts']!)) {
      throw const CreationValidation('registration');
    }
    final banner = fields['banner']!.trim();
    final uri = Uri.tryParse(banner);
    if (banner.isNotEmpty &&
        (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty)) {
      throw const CreationValidation('banner');
    }
    if (!freeOnly && fields['refund']!.trim().isEmpty) {
      throw const CreationValidation('refundPolicy');
    }
    return {
      'title': fields['title']!.trim(),
      'category': fields['category']!.trim(),
      'description': fields['description']!.trim(),
      'venue': {
        'name': fields['venue']!.trim(),
        'address': fields['address']!.trim(),
        'city': fields['city']!.trim()
      },
      'visibility': fields['visibility'],
      'capacity': positiveWhole(fields['capacity']!),
      'refund_policy': fields['refund']!.trim(),
      'starts_at': kazakhstanTimestamp(dates['starts']!),
      'ends_at': kazakhstanTimestamp(dates['ends']!),
      'registration_opens_at': kazakhstanTimestamp(dates['opens']!),
      'registration_closes_at': kazakhstanTimestamp(dates['closes']!),
      'time_zone': 'Asia/Almaty',
      'admission_type': 'general_admission'
    };
  }

  void load(Map<String, dynamic> data) {
    final venue = data['venue'] as Map;
    fields.addAll({
      'title': data['title'],
      'category': parseEventCategory(data['category']).name,
      'description': data['description'],
      'venue': venue['name'],
      'address': venue['address'],
      'city': venue['city'] ?? 'Almaty',
      'visibility': data['visibility'],
      'capacity': '${data['capacity']}',
      'refund': data['refund_policy'] ?? ''
    });
    final images = data['images'] as List? ?? [];
    fields['banner'] = images.isEmpty
        ? ''
        : (images.first is String ? images.first : images.first['url']);
    for (final entry in {
      'starts': 'starts_at',
      'ends': 'ends_at',
      'opens': 'registration_opens_at',
      'closes': 'registration_closes_at'
    }.entries) {
      dates[entry.key] = kazakhstanWallTime(parseApiDate(data[entry.value]));
    }
  }
}

class TicketDraft {
  TicketDraft(EventDraft event, {bool initial = false}) {
    fields.addAll({
      'name': initial ? 'General admission' : '',
      'description': '',
      'kind': event.freeOnly ? 'free' : 'paid',
      'price': event.freeOnly ? '0' : '',
      'quantity': initial ? event.fields['capacity']! : '1',
      'maximum': '10'
    });
    start = event.dates['opens'];
    end = event.dates['closes'];
  }
  final String key = creationKey();
  String? savedId;
  final fields = <String, String>{};
  DateTime? start, end;
  Map<String, dynamic> body(EventDraft event) {
    if (fields['name']!.trim().isEmpty) throw const CreationValidation('name');
    if (fields['kind'] == 'paid' && event.fields['refund']!.trim().isEmpty) {
      throw const CreationValidation('refundPolicy');
    }
    final quantity = positiveWhole(fields['quantity']!);
    final maximum = positiveWhole(fields['maximum']!);
    if (maximum > 50) throw const CreationValidation('maximum');
    if (start == null ||
        end == null ||
        !start!.isBefore(end!) ||
        start!.isBefore(event.dates['opens']!) ||
        end!.isAfter(event.dates['closes']!)) {
      throw const CreationValidation('sales');
    }
    final price = fields['kind'] == 'free' ? 0 : kztMinor(fields['price']!);
    if (fields['kind'] == 'paid' && price <= 0) {
      throw const CreationValidation('price');
    }
    return {
      'name': fields['name']!.trim(),
      'description': fields['description']!.trim(),
      'kind': fields['kind'],
      'price_minor': price,
      'quantity': quantity,
      'sales_start': kazakhstanTimestamp(start!),
      'sales_end': kazakhstanTimestamp(end!),
      'max_per_order': maximum
    };
  }

  void load(Map<String, dynamic> data) {
    savedId = data['id'];
    fields.addAll({
      'name': data['name'],
      'description': data['description'] ?? '',
      'kind': data['kind'],
      'price': ((data['price_minor'] as num) / 100).toStringAsFixed(2),
      'quantity': '${data['quantity']}',
      'maximum': '${data['max_per_order']}'
    });
    start = kazakhstanWallTime(parseApiDate(data['sales_start']));
    end = kazakhstanWallTime(parseApiDate(data['sales_end']));
  }
}
