import 'package:biletflow_mobile/shared/user_facing_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '53a99965-741a-4250-a074-02b9974c1652';

  test('hides internal UUIDs while preserving message content', () {
    expect(withoutInternalIds('Ticket #$id is ready.'), 'Ticket is ready.');
    expect(
        withoutInternalIds('Booking ($id) confirmed.'), 'Booking confirmed.');
    expect(withoutInternalIds('Билет $id готов.'), 'Билет готов.');
    expect(withoutInternalIds('Билет $id дайын.'), 'Билет дайын.');
    expect(withoutInternalIds('Ticket ${id.toUpperCase()} is ready.'),
        'Ticket is ready.');
    expect(withoutInternalIds('Ticket ${id.replaceAll('-', '')} is ready.'),
        'Ticket is ready.');
    expect(withoutInternalIds(id, fallback: 'Message'), 'Message');
  });

  test('preserves dates, prices, seats, promo codes and message line breaks',
      () {
    const text =
        '2026-11-26 at 18:00\n2 tickets · 12500 ₸\nSeat A-12 · JAZZ2026';
    expect(withoutInternalIds(text), text);
  });
}
