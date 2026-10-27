import 'event.dart';
import 'organizer_event_filter.dart' show eventEnd;

/// Attendance work follows the event clock; cancellation always takes precedence.
enum StaffEventFilter {
  all,
  upcoming,
  live,
  past,
  suspended,
  cancelled;

  bool matches(AppEvent event, DateTime now) {
    if (this == all) return true;
    if (event.eventStatus == 'suspended') return this == suspended;
    if (event.eventStatus == 'cancelled') return this == cancelled;
    if (event.eventStatus == 'completed' || !eventEnd(event).isAfter(now)) {
      return this == past;
    }
    if (event.date.isAfter(now)) return this == upcoming;
    return this == live;
  }
}

List<AppEvent> sortedStaffEvents(Iterable<AppEvent> events) => events.toList()
  ..sort((a, b) {
    final time = a.date.compareTo(b.date);
    return time != 0 ? time : a.id.compareTo(b.id);
  });
