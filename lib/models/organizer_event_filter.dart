import 'event.dart';

enum OrganizerEventFilter {
  all,
  draft,
  upcoming,
  active,
  past,
  completed,
  cancelled;

  bool matches(AppEvent event, DateTime now) {
    if (this == all) return true;
    if (event.eventStatus == 'draft') return this == draft;
    if (event.eventStatus == 'cancelled') return this == cancelled;
    if (event.eventStatus == 'completed') return this == completed;
    if (event.eventStatus != 'published') return false;
    if (!eventEnd(event).isAfter(now)) return this == past;
    if (event.date.isAfter(now)) return this == upcoming;
    return this == active;
  }
}

DateTime eventEnd(AppEvent event) {
  if (event.endsAt != null) return event.endsAt!;
  final parts = event.endTime.split(':');
  var end = DateTime(event.date.year, event.date.month, event.date.day,
      int.tryParse(parts.first) ?? 0, int.tryParse(parts.last) ?? 0);
  if (end.isBefore(event.date)) end = end.add(const Duration(days: 1));
  return end;
}
