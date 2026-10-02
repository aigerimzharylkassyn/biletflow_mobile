import 'package:biletflow_mobile/models/event.dart';
import 'package:biletflow_mobile/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event model reads the backend venue and inventory contract', () {
    final event = AppEvent.fromJson({
      'id': 'event-id',
      'organizer_id': 'organizer-id',
      'organizer_name': 'Example Organizer',
      'title': 'Live music',
      'description': 'A real backend event',
      'category': 'music',
      'status': 'published',
      'starts_at': '2026-11-10T13:00:00Z',
      'ends_at': '2026-11-10T15:00:00Z',
      'venue': {
        'id': 'venue-id',
        'name': 'Central Hall',
        'address': '1 Abay Avenue',
        'city': 'Almaty',
      },
      'available_ticket_types': [
        {
          'id': 'type-id',
          'name': 'General admission',
          'kind': 'paid',
          'price_minor': 250000,
          'quantity': 100,
          'reserved_count': 2,
          'sold_count': 40,
        },
      ],
    });

    expect(event.venue, 'Central Hall');
    expect(event.city, 'Almaty');
    expect(event.organizerName, 'Example Organizer');
    expect(event.price, 2500);
    expect(event.ticketsTotal, 100);
    expect(event.ticketsSold, 40);
    expect(event.isFree, isFalse);
  });

  test('event staff role is distinct from an attendee', () {
    final user = AppUser.fromJson({
      'id': 'staff-id',
      'full_name': 'Door Staff',
      'email': 'staff@example.com',
      'roles': ['attendee', 'event_admin'],
    });

    expect(user.role, UserRole.staff);
  });
}
